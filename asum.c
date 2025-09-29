#include <proto/exec.h>
#include <proto/dos.h>

#include <exec/exec.h>
#include <dos/dos.h>

#include <string.h>
#include <stdbool.h>

#include <md5.h>

#include "AsyncFile.h"

const char Version[] = "$VER: asum 0.5 (29.9.2025)";

union MD5Hash {
	ULONG longs[4];
	UBYTE bytes[16];
};

static void HexToMD5Hash(char *hex, union MD5Hash *hash);
static void MD5HashToHex(union MD5Hash *hash, char *hex);

#define BUFFER_SIZE     (64 * 1024)
#define LINEBUFFER_SIZE (4 * 1024)

LONG asum() {
	struct ExecBase *SysBase = *(struct ExecBase **) 4;
	struct RDArgs *argsResult = NULL;
	BPTR toFile = 0;
	UBYTE *buffer = NULL;
	UBYTE *buffers[2];
	unsigned currBuffer = 0;
	BPTR file = 0;
	struct AsyncFile asyncFile = {0};
	char *lineBuffer = NULL;
	struct AnchorPath *anchorPath = NULL;
	BPTR checkFile = 0;
	struct MD5Ctx *ctx = NULL;
	ULONG missingFiles = 0;
	const char *programName = "asum";
	
	LONG retVal = RETURN_FAIL;
	
	struct DosLibrary *DOSBase = (void *) OpenLibrary("dos.library", 36);
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

	buffer = AllocMem(BUFFER_SIZE * 2, MEMF_ANY);
	lineBuffer = AllocMem(LINEBUFFER_SIZE, MEMF_ANY);
	ctx = AllocMem(sizeof(*ctx), MEMF_ANY);
	if (NULL == buffer || NULL == lineBuffer || NULL == ctx) {
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
			
					if (!AsyncFileInit(SysBase, DOSBase, &asyncFile, file)) {
						PrintFault(ERROR_NO_FREE_STORE, programName);
						goto cleanup;
					}

					AsyncFileStartRead(DOSBase, &asyncFile, buffers[currBuffer], BUFFER_SIZE);

					MD5_Init(ctx);

					while (1) {
						if (SetSignal(0, SIGBREAKF_CTRL_C) & SIGBREAKF_CTRL_C) {
							retVal = RETURN_WARN;
							goto cleanup;
						}
						LONG readBytes = AsyncFileWaitForCompletion(SysBase, DOSBase, &asyncFile);
						if (-1 == readBytes) {
							PrintFault(IoErr(), fileName);
							goto cleanup;
						}
						else if (0 == readBytes) {
							break;
						}
						unsigned nextBuffer = (currBuffer + 1) & 1;
						AsyncFileStartRead(DOSBase, &asyncFile, buffers[nextBuffer], BUFFER_SIZE);
						MD5_Update(ctx, buffers[currBuffer], readBytes);
						currBuffer = nextBuffer;
					}
					AsyncFileCleanup(SysBase, DOSBase, &asyncFile);
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
			
			if (!AsyncFileInit(SysBase, DOSBase, &asyncFile, file)) {
				PrintFault(ERROR_NO_FREE_STORE, programName);
				goto cleanup;
			}

			AsyncFileStartRead(DOSBase, &asyncFile, buffers[currBuffer], BUFFER_SIZE);

			MD5_Init(ctx);
			
			while (1) {
				if (SetSignal(0, SIGBREAKF_CTRL_C) & SIGBREAKF_CTRL_C) {
					retVal = RETURN_WARN;
					goto cleanup;
				}
				LONG readBytes = AsyncFileWaitForCompletion(SysBase, DOSBase, &asyncFile);
				if (-1 == readBytes) {
					PrintFault(IoErr(), fileName);
					goto cleanup;
				}
				else if (0 == readBytes) {
					break;
				}
				unsigned nextBuffer = (currBuffer + 1) & 1;
				AsyncFileStartRead(DOSBase, &asyncFile, buffers[nextBuffer], BUFFER_SIZE);
				MD5_Update(ctx, buffers[currBuffer], readBytes);
				currBuffer = nextBuffer;
			}
			AsyncFileCleanup(SysBase, DOSBase, &asyncFile);
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
	if (NULL != ctx) {
		FreeMem(ctx, sizeof(*ctx));
	}
	if (0 != checkFile) {
		Close(checkFile);
	}
	if (NULL != anchorPath) {
		MatchEnd(anchorPath);
		FreeMem(anchorPath, sizeof(*anchorPath) + LINEBUFFER_SIZE);
	}
	AsyncFileCleanup(SysBase, DOSBase, &asyncFile);
	if (0 != file) {
		Close(file);
	}
	if (NULL != lineBuffer) {
		FreeMem(lineBuffer, LINEBUFFER_SIZE);
	}
	if (NULL != buffer) {
		FreeMem(buffer, BUFFER_SIZE * 2);
	}
	if (NULL != args.toName) {
		Close(toFile);
	}
	if (NULL != argsResult) {
		FreeArgs(argsResult);
	}
	if (NULL != DOSBase) {
		CloseLibrary((void *) DOSBase);
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
