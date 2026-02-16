/* This is used to be able to compile for OS4 with as few code changes as
 * possible.
 *
 * First of all, it makes it possible to use references to library bases by
 * redefining both the variable name and the struct of the library base as
 * the corresponding interface name and struct.
 *
 * One limitation is that code which needs access to both library base and
 * interface needs to be handled in a separate file not including this file.
 * This ties into the second thing it does and that is to handle a few such
 * common cases like that as separate functions and redefine the library
 * function of it to this function. See OS4Compatibility.c.
 *
 * Two such common cases are:
 * - OpenLibrary followed by GetInterface
 * - DropInterface followed by CloseLibrary
 *
 * Library function calling without changes for OS4 is still achieved by
 * -D__USE_INLINE__.
 */
#ifndef __OS4_COMPATIBILITY_H__
#define __OS4_COMPATIBILITY_H__

#ifdef __amigaos4__
#include <interfaces/exec.h>
struct Interface *OpenLibraryAndMainInterface(struct ExecIFace *IExec, const char *libraryName, LONG libraryVersion);
void CloseInterfaceAndLibrary(struct ExecIFace *IExec, struct Interface *interface);
#undef OpenLibrary
#define OpenLibrary(name, version) OpenLibraryAndMainInterface(IExec, name, version)
#undef CloseLibrary
#define CloseLibrary(library) CloseInterfaceAndLibrary(IExec, library)

#define Library Interface
#define ExecBase ExecIFace
#define SysBase IExec
#define DosLibrary DOSIFace
#define DOSBase IDOS
// Add more as needed

#endif

#endif
