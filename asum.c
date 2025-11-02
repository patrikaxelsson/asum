#include <proto/exec.h>
#include <proto/dos.h>
#ifdef __M68K__
#include <proto/powerpc.h>
#else
static void *AllocVec32(ULONG size, ULONG flags) {
	return NULL;
}
static void FreeVec32(void *address) {
}
#endif
#include <exec/exec.h>
#include <dos/dos.h>
#ifdef __M68K__
#include <powerpc/powerpc.h>
#else
#define PPERR_SUCCESS 0
#endif

#include <string.h>
#include <stdbool.h>

#include <md5.h>

#include "WarpOSMD5Wrapper.h"
#include "AsyncFile.h"
#include "OS4Compatibility.h"

const char Version[] = "$VER: asum 0.21 (2.11.2025) by Patrik Axelsson and K-P Koljonen";

union MD5Hash {
	ULONG longs[4];
	UBYTE bytes[16];
};

static void HexToMD5Hash(char *hex, union MD5Hash *hash);
static void MD5HashToHex(union MD5Hash *hash, char *hex);

#define BUFFER_SIZE     (64 * 1024)
#define LINEBUFFER_SIZE (4 * 1024)

LONG asum(struct ExecBase *SysBase, struct DosLibrary *DOSBase) {
	#ifdef __M68K__
	struct Library *PowerPCBase = OpenLibrary("powerpc.library", 15);
	#else
	struct Library *PowerPCBase = NULL;
	#endif
	struct RDArgs *argsResult = NULL;
	UBYTE *buffer = NULL;
	char *lineBuffer = NULL;
	struct MD5Ctx *ctx = NULL;
	struct AsyncCtx asyncCtxStore;
	struct AsyncCtx *asyncCtx;
	UBYTE *buffers[2];
	BPTR toFile = 0;
	struct AnchorPath *anchorPath = NULL;
	BPTR checkFile = 0;
	BPTR file = 0;

	const char *programName = "asum";
	ULONG missingFiles = 0;
	
	LONG retVal = RETURN_FAIL;
	if (NULL == DOSBase) {
		goto cleanup;
	}

	struct {
		const char **fileNames;
		const LONG *all;
		const char *toName;
		const char *checkName;
	} args = {0};

	argsResult = ReadArgs("FILES/M,ALL/S,TO/K,CHECK/K", (void *) &args, NULL);
	if (NULL == argsResult) {
		PrintFault(IoErr(), programName);
		goto cleanup;
	}

	if (NULL == args.fileNames && NULL == args.checkName) {
		PrintFault(ERROR_REQUIRED_ARG_MISSING, programName);
		goto cleanup;
	}

	buffer = NULL == PowerPCBase ? AllocMem(BUFFER_SIZE * 2, MEMF_ANY) : AllocVec32(BUFFER_SIZE * 2, MEMF_ANY);
	lineBuffer = AllocMem(LINEBUFFER_SIZE, MEMF_ANY);
	ctx = NULL == PowerPCBase ? AllocMem(sizeof(*ctx), MEMF_ANY) : AllocVec32(sizeof(*ctx), MEMF_ANY);
	asyncCtx = AsyncFileInit(SysBase, DOSBase, &asyncCtxStore);
	if (NULL == buffer || NULL == lineBuffer || NULL == ctx || NULL == asyncCtx) {
		PrintFault(ERROR_NO_FREE_STORE, programName);
		goto cleanup;	
	}

	buffers[0] = buffer;
	buffers[1] = buffer + BUFFER_SIZE;

	if (NULL != args.fileNames) {
		toFile = Output();
		if (NULL != args.toName) {
			toFile = Open(args.toName, MODE_NEWFILE);
			if (0 == toFile) {
				PrintFault(IoErr(), args.toName);
				goto cleanup;
			}
		}

		anchorPath = AllocMem(sizeof(*anchorPath) + LINEBUFFER_SIZE, MEMF_ANY);
		if (NULL == anchorPath) {
			PrintFault(ERROR_NO_FREE_STORE, programName);
			goto cleanup;
		}

		do {
			const char *argsFileName = *args.fileNames;
			anchorPath->ap_Base = 0;
			anchorPath->ap_BreakBits = SIGBREAKF_CTRL_C;
			anchorPath->ap_FoundBreak = 0;
			anchorPath->ap_Flags = 0;
			anchorPath->ap_Strlen = LINEBUFFER_SIZE;
			anchorPath->ap_Buf[0] = '\0';
			bool firstMatch;
			LONG matchResult;
			for (
					matchResult = MatchFirst(argsFileName, anchorPath), firstMatch = true;
					0 == matchResult;
					matchResult = MatchNext(anchorPath), firstMatch = false
				) {
				if (anchorPath->ap_Flags & APF_DIDDIR) {
					anchorPath->ap_Flags &= ~(APF_DODIR | APF_DIDDIR);
				}
				else if (anchorPath->ap_Info.fib_DirEntryType > 0) {
					anchorPath->ap_Flags |= ((args.all || firstMatch) ? APF_DODIR : 0);
				}
				else if(anchorPath->ap_Info.fib_DirEntryType < 0) {
					// Happens on NIL: or thors DEV:df0 as DEV: as neither
					// is a filesystem - Examine() should not work
					const char *fileName = '\0' != anchorPath->ap_Buf[0] ? anchorPath->ap_Buf : argsFileName;
					file = Open(fileName, MODE_OLDFILE); 
					if (0 == file) {
						PrintFault(IoErr(), fileName);
						missingFiles++;
						continue;
					}
			
					unsigned readBuffer = 0;
					unsigned calcBuffer = readBuffer;
					ULONG readUsed = 0;
					ULONG calcSize = 0;
					AsyncFileStartRead(asyncCtx, file, buffers[readBuffer], BUFFER_SIZE);

					MD5_Init(ctx);

					LONG readBytes;
					do {
						if (SetSignal(0, SIGBREAKF_CTRL_C) & SIGBREAKF_CTRL_C) {
							retVal = RETURN_WARN;
							goto cleanup;
						}
						readBytes = AsyncFileWaitForCompletion(asyncCtx, file);
						if (-1 == readBytes) {
							PrintFault(IoErr(), fileName);
							goto cleanup;
						}
						readUsed += readBytes;
						if (BUFFER_SIZE == readUsed || 0 == readBytes) {
							calcSize = readUsed;
							calcBuffer = readBuffer;
							readUsed = 0;
							readBuffer = ((readBuffer + 1) & 1);
						}
						if (0 != readBytes) {
							AsyncFileStartRead(asyncCtx, file, buffers[readBuffer] + readUsed, BUFFER_SIZE - readUsed);
						}
						if (calcSize) {
							if (NULL == PowerPCBase) {
								MD5_Update(ctx, buffers[calcBuffer], calcSize);
							}
							else {
								LONG result = WarpOS_MD5_Update(PowerPCBase, ctx, buffers[calcBuffer], calcSize);
								if (PPERR_SUCCESS != result) {
									PutStr("RunPPC fail!\n");
									goto cleanup;
								}
							}
							calcSize = 0;
						}
					} while (0 != readBytes);

					Close(file);
					file = 0;

					union MD5Hash hash;
					MD5_Final(ctx, hash.bytes);
					MD5HashToHex(&hash, lineBuffer);
					lineBuffer[32] = ' ';
					lineBuffer[33] = ' ';
					ULONG fileNameLength = strlen(fileName);
					memcpy(lineBuffer + 32 + 2, fileName, fileNameLength);
					lineBuffer[32 + 2 + fileNameLength] = '\n';
					Write(toFile, lineBuffer, 32 + 2 + fileNameLength + 1);
				}
			}
			if (ERROR_BREAK == matchResult) {
				retVal = RETURN_WARN;
				goto cleanup;
			}
			else if (ERROR_OBJECT_NOT_FOUND == matchResult) {
				PrintFault(ERROR_OBJECT_NOT_FOUND, argsFileName);
				missingFiles++;
			}
			else if (ERROR_NO_MORE_ENTRIES != matchResult) {
				PrintFault(IoErr(), argsFileName);
				goto cleanup;
			}
			MatchEnd(anchorPath);
		} while (*++args.fileNames);
	}

	if (NULL != args.checkName) {
		checkFile = Open(args.checkName, MODE_OLDFILE); 
		if (0 == checkFile) {
			PrintFault(IoErr(), args.checkName);
			goto cleanup;
		}

		unsigned failedChecksums = 0;
		while (1) {
			char *line = FGets(checkFile, lineBuffer, LINEBUFFER_SIZE);
			if (NULL == line) {
				LONG ioErr = IoErr();
				if (0 != ioErr) {
					PrintFault(ioErr, args.checkName);
					goto cleanup;
				}
				break;
			}
			ULONG lineLength = strlen(line);
			if (lineLength <= 32 + 2) {
				continue;
			}
			if (line[lineLength - 1] == '\n') {
				line[lineLength - 1] = '\0';
			}
			char *checkDigest = line;
			char *fileName = line + 32 + 2;

			file = Open(fileName, MODE_OLDFILE); 
			if (0 == file) {
				PrintFault(IoErr(), fileName);
				missingFiles++;
				continue;
			}
			
			unsigned readBuffer = 0;
			unsigned calcBuffer = readBuffer;
			ULONG readUsed = 0;
			ULONG calcSize = 0;
			AsyncFileStartRead(asyncCtx, file, buffers[readBuffer], BUFFER_SIZE);

			MD5_Init(ctx);

			LONG readBytes;
			do {
				if (SetSignal(0, SIGBREAKF_CTRL_C) & SIGBREAKF_CTRL_C) {
					retVal = RETURN_WARN;
					goto cleanup;
				}
				readBytes = AsyncFileWaitForCompletion(asyncCtx, file);
				if (-1 == readBytes) {
					PrintFault(IoErr(), fileName);
					goto cleanup;
				}
				readUsed += readBytes;
				if (BUFFER_SIZE == readUsed || 0 == readBytes) {
					calcSize = readUsed;
					calcBuffer = readBuffer;
					readUsed = 0;
					readBuffer = ((readBuffer + 1) & 1);
				}
				if (0 != readBytes) {
					AsyncFileStartRead(asyncCtx, file, buffers[readBuffer] + readUsed, BUFFER_SIZE - readUsed);
				}
				if (calcSize) {
					if (NULL == PowerPCBase) {
						MD5_Update(ctx, buffers[calcBuffer], calcSize);
					}
					else {
						LONG result = WarpOS_MD5_Update(PowerPCBase, ctx, buffers[calcBuffer], calcSize);
						if (PPERR_SUCCESS != result) {
							PutStr("RunPPC fail!\n");
							goto cleanup;
						}
					}
					calcSize = 0;
				}
			} while (0 != readBytes);

			Close(file);
			file = 0;
			
			union MD5Hash hash;
			MD5_Final(ctx, hash.bytes);
			union MD5Hash checkHash;
			HexToMD5Hash(checkDigest, &checkHash);

			if (hash.longs[0] != checkHash.longs[0] || hash.longs[1] != checkHash.longs[1] || hash.longs[2] != checkHash.longs[2] || hash.longs[3] != checkHash.longs[3]) {
				Printf("%s: MD5 mismatch!\n", fileName);
				failedChecksums++;
			}
		}
		if (failedChecksums) {
			retVal = RETURN_ERROR;
			goto cleanup;
		}
	}

	retVal = 0 != missingFiles ? RETURN_WARN : RETURN_OK;
cleanup:
	// In case of cleanup from error where it has not been waited for already
	AsyncFileWaitForCompletion(asyncCtx, file);
	if (0 != file) {
		Close(file);
	}
	if (0 != checkFile) {
		Close(checkFile);
	}
	if (NULL != anchorPath) {
		MatchEnd(anchorPath);
		FreeMem(anchorPath, sizeof(*anchorPath) + LINEBUFFER_SIZE);
	}
	if (NULL != args.toName && 0 != toFile) {
		Close(toFile);
	}
	AsyncFileCleanup(asyncCtx);
	if (NULL != ctx) {
		NULL == PowerPCBase ? FreeMem(ctx, sizeof(*ctx)) : FreeVec32(ctx);
	}
	if (NULL != lineBuffer) {
		FreeMem(lineBuffer, LINEBUFFER_SIZE);
	}
	if (NULL != buffer) {
		NULL == PowerPCBase ? FreeMem(buffer, BUFFER_SIZE * 2) : FreeVec32(buffer);
	}
	if (NULL != argsResult) {
		FreeArgs(argsResult);
	}
	if (NULL != PowerPCBase) {
		CloseLibrary(PowerPCBase);
	}
	return retVal;
}

static unsigned HexToNibble(unsigned c) {
	if (c >= 'a') {
		return (c - 'a') + 10;
	}
	else if (c >= 'A') {
		return (c - 'A') + 10;
	}
	else if (c >= '0') {
		return c - '0';
	}
	return 0;
}

static void HexToMD5Hash(char *hex, union MD5Hash *hash) {
	unsigned count = sizeof(hash->bytes);
	char *bytes = hash->bytes;
	do {
		*bytes++ = HexToNibble(*hex++) << 4 | HexToNibble(*hex++);
	} while (--count);
}

static unsigned NibbleToHex(unsigned nibble) {
	if (nibble >= 10) {
		return 'a' - 10 + nibble;
	}
	return '0' + nibble;
}

static void MD5HashToHex(union MD5Hash *hash, char *hex) {
	const unsigned char *bytes = hash->bytes;
	unsigned count = sizeof(hash->bytes);
	do {
		unsigned b = *bytes++;
		*hex++ = NibbleToHex(b >> 4); 
		*hex++ = NibbleToHex(b & 0xf); 
	} while (--count);
}
