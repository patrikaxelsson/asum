# asum

Very fast MD5 checksum tool which can be used both to generate a list of MD5
checksums and verify such list. The format of the generated list is
compatible with many other similar tools.

The main idea with this tool is to offer as quick MD5 checksum calculations
as possible, in a simple way, without extra options required.

It uses highly optimized 68k MD5 code and reasonably optimized PPC MD5 code.
The latter is utilized automatically if WarpOS is available, or if the
MorphOS or AmigaOS4 versions are used. This is coupled with asynchronous
reads, to allow the CPU to calculate the checksums, while the files are
being read in the background, which makes it very efficient with DMA
controllers.


## Thanks

* K-P Koljonen for his tireless and inspiring efforts optimizing the
  HippoPlayer MD5 code this tool is based on.
* Crab at #amihelp for all the meticulous testing and feedback.


## Usage
```
> asum ? 
FILES/M,ALL/S,TO/K,CHECK/K:
```
| Name  | Description |
| ----- | ----------- |
| FILES | Files to checksum. If directories or volumes are supplied, the contained files will be checksummed. AmigaDOS patterns can be used. |
| ALL   | Traverse directories and volumes found in FILES recursively. |
| TO    | Output the generated list of checksums to this file, instead of the standard output. |
| CHECK | Validate this previously generated list of checksums. Resultcode 10 for checksum mismatch and 5 for missing file. |


## Examples

### A couple of files
```
> C:
C> asum Dir List Version
c896a610895a36be0dea489cd6dd83ee  Dir
f300978a06ba9e5e7258ad43241126eb  List
d5c482ac3cc004d57465db051db1365c  Version
```

### Using AmigaDOS patterns
```
> asum S:#?-Startup 
c23e2afc5cea3b09bc2dcb890b441a3a  S:Network-Startup
17ab20b698004d01f1197c4e9f27ec51  S:User-Startup
e979a38b5f13a3fb8a8e67d0d3873547  S:Shell-startup
14fa4c0562f540a9d250365eb5d65818  S:Network-User-Startup
d5cae30fc54900a314dd2c6cf2175825  S:WHDLoad-Startup
```

### Generate a list of an entire partition and then verify it
```
> asum Work: ALL TO=RAM:Work.md5sums
> asum CHECK=RAM:Work.md5sums
> echo $RC
0
```

### Generate a list, change a file and then verify it catches the change
```
> asum S: TO=RAM:checkfile.md5sums
> echo "" >>S:User-Startup
> asum CHECK=RAM:checkfile.md5sums
S:User-Startup: MD5 mismatch!
> echo $RC
10
```

### Generate a list, remove a file and then verify it catches the missing file
```
> copy S:User-Startup S:User-Startup.backup
> asum S: TO=RAM:checkfile.md5sums
> delete S:User-Startup.backup
S:User-Startup.backup  Deleted
> asum CHECK=RAM:checkfile.md5sums
S:User-Startup.backup: object not found
> echo $RC
5
```


## Single file performance on various systems, controllers and OS's

### A500+ 68000@7MHz, GVP HD+8, AmigaOS 3.2
```
> UHC:C/time asum Work:test100M.bin
2f282b84e7e608d5852449ed940bfc51  Work:test100M.bin
1913.864809s
```

### A3000 68030@25MHz, internal SCSI, AmigaOS 3.2.1
```
> UHC:C/time asum Work:test100M.bin
2f282b84e7e608d5852449ed940bfc51  Work:test100M.bin
239.916814s
```

### A1200 Blizzard1260 68060@50MHz, internal IDE, AmigaOS 3.2.1
Comment: Completely bottlenecked by internal IDE
```
> UHC:C/time asum Work:test100M.bin
2f282b84e7e608d5852449ed940bfc51  Work:test100M.bin
67.635010s
```

### A1200 Blizzard1260 68060@50MHz, Blizzard SCSI Kit IV, AmigaOS 3.2.1
```
> UHC:C/time asum 1230SCSI:test100M.bin
2f282b84e7e608d5852449ed940bfc51  1230SCSI:test100M.bin
24.135190s
```

### A4000 CSPPC 68060@50MHz, 604e@200MHz, CSPPC SCSI, AmigaOS 3.9 + NoWarpOS
```
> Run NoWarpOS >NIL:
[CLI 1]
> UHC:C/time asum Work:test100M.bin
2f282b84e7e608d5852449ed940bfc51  Work:test100M.bin
21.440839s
```

### A4000 CSPPC 68060@50MHz, 604e@200MHz, CSPPC SCSI, AmigaOS 3.9 + WarpOS 16.1
```
> UHC:C/time asum Work:test100M.bin
2f282b84e7e608d5852449ed940bfc51  Work:test100M.bin
9.056016s
```

### A4000 CSPPC 68060@50MHz, 604e@200MHz, CSPPC SCSI, MorphOS 1.4
```
> UHC:C/time asum Work:test100M.bin
2f282b84e7e608d5852449ed940bfc51  Work:test100M.bin
9.483412s
```

### A4000 CSPPC 68060@50MHz, 604e@200MHz, CSPPC SCSI, AmigaOS 4.1 FE Update 3
```
> UHC:C/time asum Work:test100M.bin
2f282b84e7e608d5852449ed940bfc51  Work:test100M.bin
10.414447
```
