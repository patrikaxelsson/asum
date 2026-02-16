#include <proto/exec.h>

struct Interface *OpenLibraryAndMainInterface(struct ExecIFace *IExec, const char *libraryName, LONG libraryVersion) {
	struct Library *library = OpenLibrary(libraryName, libraryVersion);
	struct Interface *interface = GetInterface(library, "main", 1, NULL);
	if (NULL == interface) {
		CloseLibrary(library);
	}
	return interface;
}

void CloseInterfaceAndLibrary(struct ExecIFace *IExec, struct Interface *interface) {
	if (NULL == interface) {
		return;
	}
	struct Library *library = interface->Data.LibBase;
	DropInterface(interface);
	CloseLibrary(library);
}
