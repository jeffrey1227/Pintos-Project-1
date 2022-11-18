
kernel.o:     file format elf32-i386


Disassembly of section .text:

c0020058 <start>:
start:

# The loader called into us with CS = 0x2000, SS = 0x0000, ESP = 0xf000,
# but we should initialize the other segment registers.

	mov $0x2000, %ax
c0020058:	b8 00 20 8e d8       	mov    $0xd88e2000,%eax
	mov %ax, %ds
	mov %ax, %es
c002005d:	8e c0                	mov    %eax,%es

# Set string instructions to go upward.
	cld
c002005f:	fc                   	cld    
#### which returns AX = (kB of physical memory) - 1024.  This only
#### works for memory sizes <= 65 MB, which should be fine for our
#### purposes.  We cap memory at 64 MB because that's all we prepare
#### page tables for, below.

	movb $0x88, %ah
c0020060:	b4 88                	mov    $0x88,%ah
	int $0x15
c0020062:	cd 15                	int    $0x15
	addl $1024, %eax	# Total kB memory
c0020064:	66 05 00 04          	add    $0x400,%ax
c0020068:	00 00                	add    %al,(%eax)
	cmp $0x10000, %eax	# Cap at 64 MB
c002006a:	66 3d 00 00          	cmp    $0x0,%ax
c002006e:	01 00                	add    %eax,(%eax)
	jbe 1f
c0020070:	76 06                	jbe    c0020078 <start+0x20>
	mov $0x10000, %eax
c0020072:	66 b8 00 00          	mov    $0x0,%ax
c0020076:	01 00                	add    %eax,(%eax)
1:	shrl $2, %eax		# Total 4 kB pages
c0020078:	66 c1 e8 02          	shr    $0x2,%ax
	addr32 movl %eax, init_ram_pages - LOADER_PHYS_BASE - 0x20000
c002007c:	67 66 a3 5e 01       	addr16 mov %ax,0x15e
c0020081:	00 00                	add    %al,(%eax)
#### Enable A20.  Address line 20 is tied low when the machine boots,
#### which prevents addressing memory about 1 MB.  This code fixes it.

# Poll status register while busy.

1:	inb $0x64, %al
c0020083:	e4 64                	in     $0x64,%al
	testb $0x2, %al
c0020085:	a8 02                	test   $0x2,%al
	jnz 1b
c0020087:	75 fa                	jne    c0020083 <start+0x2b>

# Send command for writing output port.

	movb $0xd1, %al
c0020089:	b0 d1                	mov    $0xd1,%al
	outb %al, $0x64
c002008b:	e6 64                	out    %al,$0x64

# Poll status register while busy.

1:	inb $0x64, %al
c002008d:	e4 64                	in     $0x64,%al
	testb $0x2, %al
c002008f:	a8 02                	test   $0x2,%al
	jnz 1b
c0020091:	75 fa                	jne    c002008d <start+0x35>

# Enable A20 line.

	movb $0xdf, %al
c0020093:	b0 df                	mov    $0xdf,%al
	outb %al, $0x60
c0020095:	e6 60                	out    %al,$0x60

# Poll status register while busy.

1:	inb $0x64, %al
c0020097:	e4 64                	in     $0x64,%al
	testb $0x2, %al
c0020099:	a8 02                	test   $0x2,%al
	jnz 1b
c002009b:	75 fa                	jne    c0020097 <start+0x3f>

#### Create temporary page directory and page table and set page
#### directory base register.

# Create page directory at 0xf000 (60 kB) and fill with zeroes.
	mov $0xf00, %ax
c002009d:	b8 00 0f 8e c0       	mov    $0xc08e0f00,%eax
	mov %ax, %es
	subl %eax, %eax
c00200a2:	66 29 c0             	sub    %ax,%ax
	subl %edi, %edi
c00200a5:	66 29 ff             	sub    %di,%di
	movl $0x400, %ecx
c00200a8:	66 b9 00 04          	mov    $0x400,%cx
c00200ac:	00 00                	add    %al,(%eax)
	rep stosl
c00200ae:	66 f3 ab             	rep stos %ax,%es:(%edi)
# Add PDEs to point to page tables for the first 64 MB of RAM.
# Also add identical PDEs starting at LOADER_PHYS_BASE.
# See [IA32-v3a] section 3.7.6 "Page-Directory and Page-Table Entries"
# for a description of the bits in %eax.

	movl $0x10007, %eax
c00200b1:	66 b8 07 00          	mov    $0x7,%ax
c00200b5:	01 00                	add    %eax,(%eax)
	movl $0x11, %ecx
c00200b7:	66 b9 11 00          	mov    $0x11,%cx
c00200bb:	00 00                	add    %al,(%eax)
	subl %edi, %edi
c00200bd:	66 29 ff             	sub    %di,%di
1:	movl %eax, %es:(%di)
c00200c0:	26 66 89 05 26 66 89 	mov    %ax,%es:0x85896626
c00200c7:	85 
	movl %eax, %es:LOADER_PHYS_BASE >> 20(%di)
c00200c8:	00 0c 83             	add    %cl,(%ebx,%eax,4)
	addw $4, %di
c00200cb:	c7 04 66 05 00 10 00 	movl   $0x100005,(%esi,%eiz,2)
	addl $0x1000, %eax
c00200d2:	00 e2                	add    %ah,%dl
	loop 1b
c00200d4:	eb b8                	jmp    c002008e <start+0x36>
# Set up page tables for one-to-map linear to physical map for the
# first 64 MB of RAM.
# See [IA32-v3a] section 3.7.6 "Page-Directory and Page-Table Entries"
# for a description of the bits in %eax.

	movw $0x1000, %ax
c00200d6:	00 10                	add    %dl,(%eax)
	movw %ax, %es
c00200d8:	8e c0                	mov    %eax,%es
	movl $0x7, %eax
c00200da:	66 b8 07 00          	mov    $0x7,%ax
c00200de:	00 00                	add    %al,(%eax)
	movl $0x4000, %ecx
c00200e0:	66 b9 00 40          	mov    $0x4000,%cx
c00200e4:	00 00                	add    %al,(%eax)
	subl %edi, %edi
c00200e6:	66 29 ff             	sub    %di,%di
1:	movl %eax, %es:(%di)
c00200e9:	26 66 89 05 83 c7 04 	mov    %ax,%es:0x6604c783
c00200f0:	66 
	addw $4, %di
	addl $0x1000, %eax
c00200f1:	05 00 10 00 00       	add    $0x1000,%eax
	loop 1b
c00200f6:	e2 f1                	loop   c00200e9 <start+0x91>

# Set page directory base register.

	movl $0xf000, %eax
c00200f8:	66 b8 00 f0          	mov    $0xf000,%ax
c00200fc:	00 00                	add    %al,(%eax)
	movl %eax, %cr3
c00200fe:	0f 22 d8             	mov    %eax,%cr3
#### Switch to protected mode.

# First, disable interrupts.  We won't set up the IDT until we get
# into C code, so any interrupt would blow us away.

	cli
c0020101:	fa                   	cli    
# We need a data32 prefix to ensure that all 32 bits of the GDT
# descriptor are loaded (default is to load only 24 bits).
# The CPU doesn't need an addr32 prefix but ELF doesn't do 16-bit
# relocations.

	data32 addr32 lgdt gdtdesc - LOADER_PHYS_BASE - 0x20000
c0020102:	67 66 0f 01 15       	lgdtw  (%di)
c0020107:	58                   	pop    %eax
c0020108:	01 00                	add    %eax,(%eax)
c002010a:	00 0f                	add    %cl,(%edi)
#    WP (Write Protect): if unset, ring 0 code ignores
#       write-protect bits in page tables (!).
#    EM (Emulation): forces floating-point instructions to trap.
#       We don't support floating point.

	movl %cr0, %eax
c002010c:	20 c0                	and    %al,%al
	orl $CR0_PE | CR0_PG | CR0_WP | CR0_EM, %eax
c002010e:	66 0d 05 00          	or     $0x5,%ax
c0020112:	01 80 0f 22 c0 66    	add    %eax,0x66c0220f(%eax)
# the real-mode code segment cached in %cs's segment descriptor.  We
# need to reload %cs, and the easiest way is to use a far jump.
# Because we're not running in a 32-bit segment the data32 prefix is
# needed to jump to a 32-bit offset in the target segment.

	data32 ljmp $SEL_KCSEG, $1f
c0020118:	ea 1f 01 02 c0 08 00 	ljmp   $0x8,$0xc002011f
	.code32

# Reload all the other segment registers and the stack pointer to
# point into our new GDT.

1:	mov $SEL_KDSEG, %ax
c002011f:	66 b8 10 00          	mov    $0x10,%ax
	mov %ax, %ds
c0020123:	8e d8                	mov    %eax,%ds
	mov %ax, %es
c0020125:	8e c0                	mov    %eax,%es
	mov %ax, %fs
c0020127:	8e e0                	mov    %eax,%fs
	mov %ax, %gs
c0020129:	8e e8                	mov    %eax,%gs
	mov %ax, %ss
c002012b:	8e d0                	mov    %eax,%ss
	addl $LOADER_PHYS_BASE, %esp
c002012d:	81 c4 00 00 00 c0    	add    $0xc0000000,%esp
	movl $0, %ebp			# Null-terminate main()'s backtrace
c0020133:	bd 00 00 00 00       	mov    $0x0,%ebp

#### Call pintos_init().

	call pintos_init
c0020138:	e8 56 00 00 00       	call   c0020193 <pintos_init>

# pintos_init() shouldn't ever return.  If it does, spin.

1:	jmp 1b
c002013d:	eb fe                	jmp    c002013d <start+0xe5>
	...

c0020140 <gdt>:
	...
c0020148:	ff                   	(bad)  
c0020149:	ff 00                	incl   (%eax)
c002014b:	00 00                	add    %al,(%eax)
c002014d:	9a cf 00 ff ff 00 00 	lcall  $0x0,$0xffff00cf
c0020154:	00                   	.byte 0x0
c0020155:	92                   	xchg   %eax,%edx
c0020156:	cf                   	iret   
	...

c0020158 <gdtdesc>:
c0020158:	17                   	pop    %ss
c0020159:	00 40 01             	add    %al,0x1(%eax)
c002015c:	02 c0                	add    %al,%al

c002015e <init_ram_pages>:
c002015e:	00 00                	add    %al,(%eax)
	...

c0020162 <run_task>:
}

/* Runs the task specified in ARGV[1]. */
static void
run_task (char **argv)
{
c0020162:	53                   	push   %ebx
c0020163:	83 ec 10             	sub    $0x10,%esp
  const char *task = argv[1];
c0020166:	8b 44 24 18          	mov    0x18(%esp),%eax
c002016a:	8b 58 04             	mov    0x4(%eax),%ebx
  
  printf ("Executing '%s':\n", task);
c002016d:	53                   	push   %ebx
c002016e:	68 31 cd 02 c0       	push   $0xc002cd31
c0020173:	e8 e9 5b 00 00       	call   c0025d61 <printf>
#ifdef USERPROG
  process_wait (process_execute (task));
#else
  run_test (task);
c0020178:	89 1c 24             	mov    %ebx,(%esp)
c002017b:	e8 9c 91 00 00       	call   c002931c <run_test>
#endif
  printf ("Execution of '%s' complete.\n", task);
c0020180:	83 c4 08             	add    $0x8,%esp
c0020183:	53                   	push   %ebx
c0020184:	68 42 cd 02 c0       	push   $0xc002cd42
c0020189:	e8 d3 5b 00 00       	call   c0025d61 <printf>
}
c002018e:	83 c4 18             	add    $0x18,%esp
c0020191:	5b                   	pop    %ebx
c0020192:	c3                   	ret    

c0020193 <pintos_init>:
{
c0020193:	55                   	push   %ebp
c0020194:	57                   	push   %edi
c0020195:	56                   	push   %esi
c0020196:	53                   	push   %ebx
c0020197:	83 ec 6c             	sub    $0x6c,%esp
  memset (&_start_bss, 0, &_end_bss - &_start_bss);
c002019a:	b9 ed 84 03 c0       	mov    $0xc00384ed,%ecx
c002019f:	81 e9 08 69 03 c0    	sub    $0xc0036908,%ecx
c00201a5:	ba 08 69 03 c0       	mov    $0xc0036908,%edx
c00201aa:	b0 00                	mov    $0x0,%al
c00201ac:	89 d7                	mov    %edx,%edi
c00201ae:	f3 aa                	rep stos %al,%es:(%edi)
  argc = *(uint32_t *) ptov (LOADER_ARG_CNT);
c00201b0:	8b 3d 3a 7d 00 c0    	mov    0xc0007d3a,%edi
  for (i = 0; i < argc; i++) 
c00201b6:	85 ff                	test   %edi,%edi
c00201b8:	0f 8e 7c 05 00 00    	jle    c002073a <pintos_init+0x5a7>
c00201be:	be 00 00 00 00       	mov    $0x0,%esi
c00201c3:	bb 3e 7d 00 c0       	mov    $0xc0007d3e,%ebx
      p += strnlen (p, end - p) + 1;
c00201c8:	bd be 7d 00 c0       	mov    $0xc0007dbe,%ebp
c00201cd:	eb 08                	jmp    c00201d7 <pintos_init+0x44>
      if (p >= end)
c00201cf:	81 fb bd 7d 00 c0    	cmp    $0xc0007dbd,%ebx
c00201d5:	77 43                	ja     c002021a <pintos_init+0x87>
      argv[i] = p;
c00201d7:	89 1c b5 20 69 03 c0 	mov    %ebx,-0x3ffc96e0(,%esi,4)
      p += strnlen (p, end - p) + 1;
c00201de:	83 ec 08             	sub    $0x8,%esp
c00201e1:	89 e8                	mov    %ebp,%eax
c00201e3:	29 d8                	sub    %ebx,%eax
c00201e5:	50                   	push   %eax
c00201e6:	53                   	push   %ebx
c00201e7:	e8 f2 6c 00 00       	call   c0026ede <strnlen>
c00201ec:	8d 5c 03 01          	lea    0x1(%ebx,%eax,1),%ebx
  for (i = 0; i < argc; i++) 
c00201f0:	46                   	inc    %esi
c00201f1:	83 c4 10             	add    $0x10,%esp
c00201f4:	39 f7                	cmp    %esi,%edi
c00201f6:	75 d7                	jne    c00201cf <pintos_init+0x3c>
  argv[argc] = NULL;
c00201f8:	c7 04 b5 20 69 03 c0 	movl   $0x0,-0x3ffc96e0(,%esi,4)
c00201ff:	00 00 00 00 
  printf ("Kernel command line:");
c0020203:	83 ec 0c             	sub    $0xc,%esp
c0020206:	68 29 ce 02 c0       	push   $0xc002ce29
c002020b:	e8 51 5b 00 00       	call   c0025d61 <printf>
c0020210:	83 c4 10             	add    $0x10,%esp
c0020213:	bb 00 00 00 00       	mov    $0x0,%ebx
c0020218:	eb 33                	jmp    c002024d <pintos_init+0xba>
        PANIC ("command line arguments overflow");
c002021a:	68 48 ce 02 c0       	push   $0xc002ce48
c002021f:	68 a8 b6 02 c0       	push   $0xc002b6a8
c0020224:	68 f2 00 00 00       	push   $0xf2
c0020229:	68 5f cd 02 c0       	push   $0xc002cd5f
c002022e:	e8 dc 75 00 00       	call   c002780f <debug_panic>
      printf (" %s", argv[i]);
c0020233:	83 ec 08             	sub    $0x8,%esp
c0020236:	56                   	push   %esi
c0020237:	68 5f db 02 c0       	push   $0xc002db5f
c002023c:	e8 20 5b 00 00       	call   c0025d61 <printf>
c0020241:	83 c4 10             	add    $0x10,%esp
  for (i = 0; i < argc; i++)
c0020244:	43                   	inc    %ebx
c0020245:	39 df                	cmp    %ebx,%edi
c0020247:	0f 84 08 05 00 00    	je     c0020755 <pintos_init+0x5c2>
    if (strchr (argv[i], ' ') == NULL)
c002024d:	8b 34 9d 20 69 03 c0 	mov    -0x3ffc96e0(,%ebx,4),%esi
c0020254:	83 ec 08             	sub    $0x8,%esp
c0020257:	6a 20                	push   $0x20
c0020259:	56                   	push   %esi
c002025a:	e8 c8 69 00 00       	call   c0026c27 <strchr>
c002025f:	83 c4 10             	add    $0x10,%esp
c0020262:	85 c0                	test   %eax,%eax
c0020264:	74 cd                	je     c0020233 <pintos_init+0xa0>
      printf (" '%s'", argv[i]);
c0020266:	83 ec 08             	sub    $0x8,%esp
c0020269:	56                   	push   %esi
c002026a:	68 74 cd 02 c0       	push   $0xc002cd74
c002026f:	e8 ed 5a 00 00       	call   c0025d61 <printf>
c0020274:	83 c4 10             	add    $0x10,%esp
c0020277:	eb cb                	jmp    c0020244 <pintos_init+0xb1>
/* Prints a kernel command line help message and powers off the
   machine. */
static void
usage (void)
{
  printf ("\nCommand line syntax: [OPTION...] [ACTION...]\n"
c0020279:	83 ec 0c             	sub    $0xc,%esp
c002027c:	68 68 ce 02 c0       	push   $0xc002ce68
c0020281:	e8 d7 8f 00 00       	call   c002925d <puts>
          "  -mlfqs             Use multi-level feedback queue scheduler.\n"
#ifdef USERPROG
          "  -ul=COUNT          Limit user memory to COUNT pages.\n"
#endif
          );
  shutdown_power_off ();
c0020286:	e8 99 53 00 00       	call   c0025624 <shutdown_power_off>
        shutdown_configure (SHUTDOWN_POWER_OFF);
c002028b:	83 ec 0c             	sub    $0xc,%esp
c002028e:	6a 01                	push   $0x1
c0020290:	e8 19 53 00 00       	call   c00255ae <shutdown_configure>
c0020295:	83 c4 10             	add    $0x10,%esp
  for (; *argv != NULL && **argv == '-'; argv++)
c0020298:	83 c5 04             	add    $0x4,%ebp
c002029b:	8b 45 00             	mov    0x0(%ebp),%eax
c002029e:	85 c0                	test   %eax,%eax
c00202a0:	0f 84 07 01 00 00    	je     c00203ad <pintos_init+0x21a>
c00202a6:	80 38 2d             	cmpb   $0x2d,(%eax)
c00202a9:	0f 85 fe 00 00 00    	jne    c00203ad <pintos_init+0x21a>
      char *name = strtok_r (*argv, "=", &save_ptr);
c00202af:	83 ec 04             	sub    $0x4,%esp
c00202b2:	53                   	push   %ebx
c00202b3:	68 f1 d9 02 c0       	push   $0xc002d9f1
c00202b8:	50                   	push   %eax
c00202b9:	e8 71 6a 00 00       	call   c0026d2f <strtok_r>
c00202be:	89 c6                	mov    %eax,%esi
c00202c0:	89 44 24 10          	mov    %eax,0x10(%esp)
      char *value = strtok_r (NULL, "", &save_ptr);
c00202c4:	83 c4 0c             	add    $0xc,%esp
c00202c7:	53                   	push   %ebx
c00202c8:	68 03 da 02 c0       	push   $0xc002da03
c00202cd:	6a 00                	push   $0x0
c00202cf:	e8 5b 6a 00 00       	call   c0026d2f <strtok_r>
      if (!strcmp (name, "-h"))
c00202d4:	bf 7a cd 02 c0       	mov    $0xc002cd7a,%edi
c00202d9:	b9 03 00 00 00       	mov    $0x3,%ecx
c00202de:	f3 a6                	repz cmpsb %es:(%edi),%ds:(%esi)
c00202e0:	0f 97 c1             	seta   %cl
c00202e3:	0f 92 c2             	setb   %dl
c00202e6:	83 c4 10             	add    $0x10,%esp
c00202e9:	38 d1                	cmp    %dl,%cl
c00202eb:	74 8c                	je     c0020279 <pintos_init+0xe6>
      else if (!strcmp (name, "-q"))
c00202ed:	bf 7d cd 02 c0       	mov    $0xc002cd7d,%edi
c00202f2:	b9 03 00 00 00       	mov    $0x3,%ecx
c00202f7:	8b 34 24             	mov    (%esp),%esi
c00202fa:	f3 a6                	repz cmpsb %es:(%edi),%ds:(%esi)
c00202fc:	0f 97 c1             	seta   %cl
c00202ff:	0f 92 c2             	setb   %dl
c0020302:	38 d1                	cmp    %dl,%cl
c0020304:	74 85                	je     c002028b <pintos_init+0xf8>
      else if (!strcmp (name, "-r"))
c0020306:	bf 80 cd 02 c0       	mov    $0xc002cd80,%edi
c002030b:	b9 03 00 00 00       	mov    $0x3,%ecx
c0020310:	8b 34 24             	mov    (%esp),%esi
c0020313:	f3 a6                	repz cmpsb %es:(%edi),%ds:(%esi)
c0020315:	0f 97 c1             	seta   %cl
c0020318:	0f 92 c2             	setb   %dl
c002031b:	38 d1                	cmp    %dl,%cl
c002031d:	74 3e                	je     c002035d <pintos_init+0x1ca>
      else if (!strcmp (name, "-rs"))
c002031f:	bf 83 cd 02 c0       	mov    $0xc002cd83,%edi
c0020324:	b9 04 00 00 00       	mov    $0x4,%ecx
c0020329:	8b 34 24             	mov    (%esp),%esi
c002032c:	f3 a6                	repz cmpsb %es:(%edi),%ds:(%esi)
c002032e:	0f 97 c1             	seta   %cl
c0020331:	0f 92 c2             	setb   %dl
c0020334:	38 d1                	cmp    %dl,%cl
c0020336:	74 37                	je     c002036f <pintos_init+0x1dc>
      else if (!strcmp (name, "-mlfqs"))
c0020338:	bf 87 cd 02 c0       	mov    $0xc002cd87,%edi
c002033d:	b9 07 00 00 00       	mov    $0x7,%ecx
c0020342:	8b 34 24             	mov    (%esp),%esi
c0020345:	f3 a6                	repz cmpsb %es:(%edi),%ds:(%esi)
c0020347:	0f 97 c2             	seta   %dl
c002034a:	0f 92 c0             	setb   %al
c002034d:	38 c2                	cmp    %al,%dl
c002034f:	75 37                	jne    c0020388 <pintos_init+0x1f5>
        thread_mlfqs = true;
c0020351:	c6 05 ec 84 03 c0 01 	movb   $0x1,0xc00384ec
c0020358:	e9 3b ff ff ff       	jmp    c0020298 <pintos_init+0x105>
        shutdown_configure (SHUTDOWN_REBOOT);
c002035d:	83 ec 0c             	sub    $0xc,%esp
c0020360:	6a 02                	push   $0x2
c0020362:	e8 47 52 00 00       	call   c00255ae <shutdown_configure>
c0020367:	83 c4 10             	add    $0x10,%esp
c002036a:	e9 29 ff ff ff       	jmp    c0020298 <pintos_init+0x105>
        random_init (atoi (value));
c002036f:	83 ec 0c             	sub    $0xc,%esp
c0020372:	50                   	push   %eax
c0020373:	e8 33 65 00 00       	call   c00268ab <atoi>
c0020378:	89 04 24             	mov    %eax,(%esp)
c002037b:	e8 5e 54 00 00       	call   c00257de <random_init>
c0020380:	83 c4 10             	add    $0x10,%esp
c0020383:	e9 10 ff ff ff       	jmp    c0020298 <pintos_init+0x105>
        PANIC ("unknown option `%s' (use -h for help)", name);
c0020388:	83 ec 0c             	sub    $0xc,%esp
c002038b:	ff 74 24 0c          	pushl  0xc(%esp)
c002038f:	68 38 d0 02 c0       	push   $0xc002d038
c0020394:	68 98 b6 02 c0       	push   $0xc002b698
c0020399:	68 2b 01 00 00       	push   $0x12b
c002039e:	68 5f cd 02 c0       	push   $0xc002cd5f
c00203a3:	e8 67 74 00 00       	call   c002780f <debug_panic>
  for (; *argv != NULL && **argv == '-'; argv++)
c00203a8:	bd 20 69 03 c0       	mov    $0xc0036920,%ebp
  random_init (rtc_get_time ());
c00203ad:	e8 69 50 00 00       	call   c002541b <rtc_get_time>
c00203b2:	83 ec 0c             	sub    $0xc,%esp
c00203b5:	50                   	push   %eax
c00203b6:	e8 23 54 00 00       	call   c00257de <random_init>
  thread_init ();
c00203bb:	e8 08 05 00 00       	call   c00208c8 <thread_init>
  console_init ();  
c00203c0:	e8 27 8e 00 00       	call   c00291ec <console_init>
  printf ("Pintos booting with %'"PRIu32" kB RAM...\n",
c00203c5:	83 c4 08             	add    $0x8,%esp
          init_ram_pages * PGSIZE / 1024);
c00203c8:	a1 5e 01 02 c0       	mov    0xc002015e,%eax
c00203cd:	c1 e0 0c             	shl    $0xc,%eax
  printf ("Pintos booting with %'"PRIu32" kB RAM...\n",
c00203d0:	c1 e8 0a             	shr    $0xa,%eax
c00203d3:	50                   	push   %eax
c00203d4:	68 60 d0 02 c0       	push   $0xc002d060
c00203d9:	e8 83 59 00 00       	call   c0025d61 <printf>
  palloc_init (user_page_limit);
c00203de:	c7 04 24 ff ff ff ff 	movl   $0xffffffff,(%esp)
c00203e5:	e8 fd 25 00 00       	call   c00229e7 <palloc_init>
  malloc_init ();
c00203ea:	e8 a7 29 00 00       	call   c0022d96 <malloc_init>
  pd = init_page_dir = palloc_get_page (PAL_ASSERT | PAL_ZERO);
c00203ef:	c7 04 24 03 00 00 00 	movl   $0x3,(%esp)
c00203f6:	e8 15 27 00 00       	call   c0022b10 <palloc_get_page>
c00203fb:	89 44 24 18          	mov    %eax,0x18(%esp)
c00203ff:	a3 e8 84 03 c0       	mov    %eax,0xc00384e8
  for (page = 0; page < init_ram_pages; page++)
c0020404:	83 c4 10             	add    $0x10,%esp
c0020407:	83 3d 5e 01 02 c0 00 	cmpl   $0x0,0xc002015e
c002040e:	0f 84 23 01 00 00    	je     c0020537 <pintos_init+0x3a4>
c0020414:	bf 00 00 00 c0       	mov    $0xc0000000,%edi
c0020419:	b8 00 00 00 00       	mov    $0x0,%eax
c002041e:	be 00 00 00 00       	mov    $0x0,%esi
      bool in_kernel_text = &_start <= vaddr && vaddr < &_end_kernel_text;
c0020423:	89 6c 24 0c          	mov    %ebp,0xc(%esp)
c0020427:	eb 5b                	jmp    c0020484 <pintos_init+0x2f1>
  for (; *argv != NULL && **argv == '-'; argv++)
c0020429:	bd 20 69 03 c0       	mov    $0xc0036920,%ebp
c002042e:	e9 7a ff ff ff       	jmp    c00203ad <pintos_init+0x21a>
      bool in_kernel_text = &_start <= vaddr && vaddr < &_end_kernel_text;
c0020433:	b1 00                	mov    $0x0,%cl
c0020435:	83 e1 01             	and    $0x1,%ecx
c0020438:	88 0c 24             	mov    %cl,(%esp)
      if (pd[pde_idx] == 0)
c002043b:	8b 4c 24 08          	mov    0x8(%esp),%ecx
c002043f:	8d 2c 91             	lea    (%ecx,%edx,4),%ebp
c0020442:	83 7d 00 00          	cmpl   $0x0,0x0(%ebp)
c0020446:	74 63                	je     c00204ab <pintos_init+0x318>
      pt[pte_idx] = pte_create_kernel (vaddr, !in_kernel_text);
c0020448:	8d 0c 98             	lea    (%eax,%ebx,4),%ecx
/* Returns physical address at which kernel virtual address VADDR
   is mapped. */
static inline uintptr_t
vtop (const void *vaddr)
{
  ASSERT (is_kernel_vaddr (vaddr));
c002044b:	81 7c 24 04 ff ff ff 	cmpl   $0xbfffffff,0x4(%esp)
c0020452:	bf 
c0020453:	0f 86 bc 00 00 00    	jbe    c0020515 <pintos_init+0x382>

  return (uintptr_t) vaddr - (uintptr_t) PHYS_BASE;
c0020459:	8d 97 00 00 00 40    	lea    0x40000000(%edi),%edx
   The PTE's page is readable.
   If WRITABLE is true then it will be writable as well.
   The page will be usable only by ring 0 code (the kernel). */
static inline uint32_t pte_create_kernel (void *page, bool writable) {
  ASSERT (pg_ofs (page) == 0);
  return vtop (page) | PTE_P | (writable ? PTE_W : 0);
c002045f:	8a 1c 24             	mov    (%esp),%bl
c0020462:	83 f3 01             	xor    $0x1,%ebx
c0020465:	0f b6 db             	movzbl %bl,%ebx
c0020468:	d1 e3                	shl    %ebx
c002046a:	83 ca 01             	or     $0x1,%edx
c002046d:	09 da                	or     %ebx,%edx
c002046f:	89 11                	mov    %edx,(%ecx)
  for (page = 0; page < init_ram_pages; page++)
c0020471:	46                   	inc    %esi
c0020472:	3b 35 5e 01 02 c0    	cmp    0xc002015e,%esi
c0020478:	0f 83 b5 00 00 00    	jae    c0020533 <pintos_init+0x3a0>
c002047e:	81 c7 00 10 00 00    	add    $0x1000,%edi
  return (uintptr_t) va >> PDSHIFT;
c0020484:	89 fa                	mov    %edi,%edx
c0020486:	c1 ea 16             	shr    $0x16,%edx
  return ((uintptr_t) va & PTMASK) >> PTSHIFT;
c0020489:	89 fb                	mov    %edi,%ebx
c002048b:	c1 eb 0c             	shr    $0xc,%ebx
c002048e:	81 e3 ff 03 00 00    	and    $0x3ff,%ebx
c0020494:	89 7c 24 04          	mov    %edi,0x4(%esp)
      bool in_kernel_text = &_start <= vaddr && vaddr < &_end_kernel_text;
c0020498:	81 ff 00 00 02 c0    	cmp    $0xc0020000,%edi
c002049e:	72 93                	jb     c0020433 <pintos_init+0x2a0>
c00204a0:	81 ff 00 00 03 c0    	cmp    $0xc0030000,%edi
c00204a6:	0f 92 c1             	setb   %cl
c00204a9:	eb 8a                	jmp    c0020435 <pintos_init+0x2a2>
          pt = palloc_get_page (PAL_ASSERT | PAL_ZERO);
c00204ab:	83 ec 0c             	sub    $0xc,%esp
c00204ae:	6a 03                	push   $0x3
c00204b0:	e8 5b 26 00 00       	call   c0022b10 <palloc_get_page>
  return (uintptr_t) va & PGMASK;
c00204b5:	89 c2                	mov    %eax,%edx
  ASSERT (pg_ofs (pt) == 0);
c00204b7:	83 c4 10             	add    $0x10,%esp
c00204ba:	a9 ff 0f 00 00       	test   $0xfff,%eax
c00204bf:	75 18                	jne    c00204d9 <pintos_init+0x346>
  ASSERT (is_kernel_vaddr (vaddr));
c00204c1:	3d ff ff ff bf       	cmp    $0xbfffffff,%eax
c00204c6:	76 2f                	jbe    c00204f7 <pintos_init+0x364>
  return (uintptr_t) vaddr - (uintptr_t) PHYS_BASE;
c00204c8:	81 c2 00 00 00 40    	add    $0x40000000,%edx
  return vtop (pt) | PTE_U | PTE_P | PTE_W;
c00204ce:	83 ca 07             	or     $0x7,%edx
c00204d1:	89 55 00             	mov    %edx,0x0(%ebp)
c00204d4:	e9 6f ff ff ff       	jmp    c0020448 <pintos_init+0x2b5>
  ASSERT (pg_ofs (pt) == 0);
c00204d9:	83 ec 0c             	sub    $0xc,%esp
c00204dc:	68 8e cd 02 c0       	push   $0xc002cd8e
c00204e1:	68 9f cd 02 c0       	push   $0xc002cd9f
c00204e6:	68 8c b6 02 c0       	push   $0xc002b68c
c00204eb:	6a 48                	push   $0x48
c00204ed:	68 b6 cd 02 c0       	push   $0xc002cdb6
c00204f2:	e8 18 73 00 00       	call   c002780f <debug_panic>
  ASSERT (is_kernel_vaddr (vaddr));
c00204f7:	83 ec 0c             	sub    $0xc,%esp
c00204fa:	68 ca cd 02 c0       	push   $0xc002cdca
c00204ff:	68 9f cd 02 c0       	push   $0xc002cd9f
c0020504:	68 84 b6 02 c0       	push   $0xc002b684
c0020509:	6a 54                	push   $0x54
c002050b:	68 e2 cd 02 c0       	push   $0xc002cde2
c0020510:	e8 fa 72 00 00       	call   c002780f <debug_panic>
c0020515:	83 ec 0c             	sub    $0xc,%esp
c0020518:	68 ca cd 02 c0       	push   $0xc002cdca
c002051d:	68 9f cd 02 c0       	push   $0xc002cd9f
c0020522:	68 84 b6 02 c0       	push   $0xc002b684
c0020527:	6a 54                	push   $0x54
c0020529:	68 e2 cd 02 c0       	push   $0xc002cde2
c002052e:	e8 dc 72 00 00       	call   c002780f <debug_panic>
c0020533:	8b 6c 24 0c          	mov    0xc(%esp),%ebp
  asm volatile ("movl %0, %%cr3" : : "r" (vtop (init_page_dir)));
c0020537:	a1 e8 84 03 c0       	mov    0xc00384e8,%eax
c002053c:	3d ff ff ff bf       	cmp    $0xbfffffff,%eax
c0020541:	76 4c                	jbe    c002058f <pintos_init+0x3fc>
  return (uintptr_t) vaddr - (uintptr_t) PHYS_BASE;
c0020543:	05 00 00 00 40       	add    $0x40000000,%eax
c0020548:	0f 22 d8             	mov    %eax,%cr3
  intr_init ();
c002054b:	e8 25 0d 00 00       	call   c0021275 <intr_init>
  timer_init ();
c0020550:	e8 1a 2e 00 00       	call   c002336f <timer_init>
  kbd_init ();
c0020555:	e8 b9 32 00 00       	call   c0023813 <kbd_init>
  input_init ();
c002055a:	e8 50 4a 00 00       	call   c0024faf <input_init>
  thread_start ();
c002055f:	e8 b3 05 00 00       	call   c0020b17 <thread_start>
  serial_init_queue ();
c0020564:	e8 ae 36 00 00       	call   c0023c17 <serial_init_queue>
  timer_calibrate ();
c0020569:	e8 27 2e 00 00       	call   c0023395 <timer_calibrate>
  printf ("Boot complete.\n");
c002056e:	83 ec 0c             	sub    $0xc,%esp
c0020571:	68 f8 cd 02 c0       	push   $0xc002cdf8
c0020576:	e8 e2 8c 00 00       	call   c002925d <puts>
  if (*argv != NULL) {
c002057b:	8b 75 00             	mov    0x0(%ebp),%esi
c002057e:	83 c4 10             	add    $0x10,%esp
c0020581:	85 f6                	test   %esi,%esi
c0020583:	74 28                	je     c00205ad <pintos_init+0x41a>
  return vtop (page) | PTE_P | (writable ? PTE_W : 0);
c0020585:	bf 8e d3 02 c0       	mov    $0xc002d38e,%edi
c002058a:	e9 81 00 00 00       	jmp    c0020610 <pintos_init+0x47d>
  ASSERT (is_kernel_vaddr (vaddr));
c002058f:	83 ec 0c             	sub    $0xc,%esp
c0020592:	68 ca cd 02 c0       	push   $0xc002cdca
c0020597:	68 9f cd 02 c0       	push   $0xc002cd9f
c002059c:	68 84 b6 02 c0       	push   $0xc002b684
c00205a1:	6a 54                	push   $0x54
c00205a3:	68 e2 cd 02 c0       	push   $0xc002cde2
c00205a8:	e8 62 72 00 00       	call   c002780f <debug_panic>
c00205ad:	8d 6c 24 61          	lea    0x61(%esp),%ebp
c00205b1:	e9 e2 00 00 00       	jmp    c0020698 <pintos_init+0x505>
      for (i = 1; i < a->argc; i++)
c00205b6:	8b 53 04             	mov    0x4(%ebx),%edx
c00205b9:	83 fa 01             	cmp    $0x1,%edx
c00205bc:	7e 36                	jle    c00205f4 <pintos_init+0x461>
        if (argv[i] == NULL)
c00205be:	83 7d 04 00          	cmpl   $0x0,0x4(%ebp)
c00205c2:	74 11                	je     c00205d5 <pintos_init+0x442>
c00205c4:	b8 01 00 00 00       	mov    $0x1,%eax
      for (i = 1; i < a->argc; i++)
c00205c9:	40                   	inc    %eax
c00205ca:	39 d0                	cmp    %edx,%eax
c00205cc:	74 26                	je     c00205f4 <pintos_init+0x461>
        if (argv[i] == NULL)
c00205ce:	83 7c 85 00 00       	cmpl   $0x0,0x0(%ebp,%eax,4)
c00205d3:	75 f4                	jne    c00205c9 <pintos_init+0x436>
          PANIC ("action `%s' requires %d argument(s)", *argv, a->argc - 1);
c00205d5:	83 ec 08             	sub    $0x8,%esp
c00205d8:	4a                   	dec    %edx
c00205d9:	52                   	push   %edx
c00205da:	56                   	push   %esi
c00205db:	68 ac d0 02 c0       	push   $0xc002d0ac
c00205e0:	68 60 b6 02 c0       	push   $0xc002b660
c00205e5:	68 74 01 00 00       	push   $0x174
c00205ea:	68 5f cd 02 c0       	push   $0xc002cd5f
c00205ef:	e8 1b 72 00 00       	call   c002780f <debug_panic>
      a->function (argv);
c00205f4:	83 ec 0c             	sub    $0xc,%esp
c00205f7:	55                   	push   %ebp
c00205f8:	ff 53 08             	call   *0x8(%ebx)
      argv += a->argc;
c00205fb:	8b 43 04             	mov    0x4(%ebx),%eax
c00205fe:	8d 6c 85 00          	lea    0x0(%ebp,%eax,4),%ebp
  while (*argv != NULL)
c0020602:	8b 75 00             	mov    0x0(%ebp),%esi
c0020605:	83 c4 10             	add    $0x10,%esp
c0020608:	85 f6                	test   %esi,%esi
c002060a:	0f 84 20 01 00 00    	je     c0020730 <pintos_init+0x59d>
c0020610:	89 f8                	mov    %edi,%eax
c0020612:	bb 6c b6 02 c0       	mov    $0xc002b66c,%ebx
        else if (!strcmp (*argv, a->name))
c0020617:	83 ec 08             	sub    $0x8,%esp
c002061a:	50                   	push   %eax
c002061b:	56                   	push   %esi
c002061c:	e8 a3 65 00 00       	call   c0026bc4 <strcmp>
c0020621:	83 c4 10             	add    $0x10,%esp
c0020624:	85 c0                	test   %eax,%eax
c0020626:	74 8e                	je     c00205b6 <pintos_init+0x423>
      for (a = actions; ; a++)
c0020628:	83 c3 0c             	add    $0xc,%ebx
        if (a->name == NULL)
c002062b:	8b 03                	mov    (%ebx),%eax
c002062d:	85 c0                	test   %eax,%eax
c002062f:	75 e6                	jne    c0020617 <pintos_init+0x484>
          PANIC ("unknown action `%s' (use -h for help)", *argv);
c0020631:	83 ec 0c             	sub    $0xc,%esp
c0020634:	56                   	push   %esi
c0020635:	68 84 d0 02 c0       	push   $0xc002d084
c002063a:	68 60 b6 02 c0       	push   $0xc002b660
c002063f:	68 6d 01 00 00       	push   $0x16d
c0020644:	68 5f cd 02 c0       	push   $0xc002cd5f
c0020649:	e8 c1 71 00 00       	call   c002780f <debug_panic>
      if(strcmp(whoami_command, input_buffer) == 0){
c002064e:	83 ec 08             	sub    $0x8,%esp
c0020651:	8d 44 24 28          	lea    0x28(%esp),%eax
c0020655:	50                   	push   %eax
c0020656:	8d 44 24 25          	lea    0x25(%esp),%eax
c002065a:	50                   	push   %eax
c002065b:	e8 64 65 00 00       	call   c0026bc4 <strcmp>
c0020660:	83 c4 10             	add    $0x10,%esp
c0020663:	85 c0                	test   %eax,%eax
c0020665:	0f 84 b0 00 00 00    	je     c002071b <pintos_init+0x588>
      else if(strcmp(exit_command, input_buffer) == 0){
c002066b:	83 ec 08             	sub    $0x8,%esp
c002066e:	8d 44 24 28          	lea    0x28(%esp),%eax
c0020672:	50                   	push   %eax
c0020673:	8d 44 24 20          	lea    0x20(%esp),%eax
c0020677:	50                   	push   %eax
c0020678:	e8 47 65 00 00       	call   c0026bc4 <strcmp>
c002067d:	83 c4 10             	add    $0x10,%esp
c0020680:	85 c0                	test   %eax,%eax
c0020682:	0f 84 a8 00 00 00    	je     c0020730 <pintos_init+0x59d>
        printf("invalid input!");
c0020688:	83 ec 0c             	sub    $0xc,%esp
c002068b:	68 1a ce 02 c0       	push   $0xc002ce1a
c0020690:	e8 cc 56 00 00       	call   c0025d61 <printf>
c0020695:	83 c4 10             	add    $0x10,%esp
      printf("\nICS143A> ");
c0020698:	83 ec 0c             	sub    $0xc,%esp
c002069b:	68 07 ce 02 c0       	push   $0xc002ce07
c00206a0:	e8 bc 56 00 00       	call   c0025d61 <printf>
      char input_buffer[64] = {'\0'};
c00206a5:	8d 7c 24 30          	lea    0x30(%esp),%edi
c00206a9:	b9 10 00 00 00       	mov    $0x10,%ecx
c00206ae:	b8 00 00 00 00       	mov    $0x0,%eax
c00206b3:	f3 ab                	rep stos %eax,%es:(%edi)
      char whoami_command[] = "whoami";
c00206b5:	8d 7c 24 29          	lea    0x29(%esp),%edi
c00206b9:	be 3e ce 02 c0       	mov    $0xc002ce3e,%esi
c00206be:	b9 07 00 00 00       	mov    $0x7,%ecx
c00206c3:	f3 a4                	rep movsb %ds:(%esi),%es:(%edi)
      char exit_command[] = "exit";
c00206c5:	c7 44 24 24 65 78 69 	movl   $0x74697865,0x24(%esp)
c00206cc:	74 
c00206cd:	c6 44 24 28 00       	movb   $0x0,0x28(%esp)
c00206d2:	8d 74 24 30          	lea    0x30(%esp),%esi
      while ((input = input_getc())){
c00206d6:	83 c4 10             	add    $0x10,%esp
c00206d9:	e8 5e 49 00 00       	call   c002503c <input_getc>
c00206de:	89 c7                	mov    %eax,%edi
c00206e0:	0f b6 d8             	movzbl %al,%ebx
c00206e3:	85 db                	test   %ebx,%ebx
c00206e5:	0f 84 63 ff ff ff    	je     c002064e <pintos_init+0x4bb>
        printf("%c", input);
c00206eb:	83 ec 0c             	sub    $0xc,%esp
c00206ee:	53                   	push   %ebx
c00206ef:	e8 d5 8b 00 00       	call   c00292c9 <putchar>
        if(input == 10){
c00206f4:	83 c4 10             	add    $0x10,%esp
c00206f7:	83 fb 0a             	cmp    $0xa,%ebx
c00206fa:	0f 84 4e ff ff ff    	je     c002064e <pintos_init+0x4bb>
        input_buffer[i] = input;
c0020700:	89 f8                	mov    %edi,%eax
c0020702:	88 06                	mov    %al,(%esi)
c0020704:	46                   	inc    %esi
        if(i > 64){
c0020705:	39 ee                	cmp    %ebp,%esi
c0020707:	75 d0                	jne    c00206d9 <pintos_init+0x546>
          printf("\n");
c0020709:	83 ec 0c             	sub    $0xc,%esp
c002070c:	6a 0a                	push   $0xa
c002070e:	e8 b6 8b 00 00       	call   c00292c9 <putchar>
          break;
c0020713:	83 c4 10             	add    $0x10,%esp
c0020716:	e9 33 ff ff ff       	jmp    c002064e <pintos_init+0x4bb>
        printf("Jeffrey");
c002071b:	83 ec 0c             	sub    $0xc,%esp
c002071e:	68 12 ce 02 c0       	push   $0xc002ce12
c0020723:	e8 39 56 00 00       	call   c0025d61 <printf>
        continue;
c0020728:	83 c4 10             	add    $0x10,%esp
c002072b:	e9 68 ff ff ff       	jmp    c0020698 <pintos_init+0x505>
  shutdown ();
c0020730:	e8 6e 4f 00 00       	call   c00256a3 <shutdown>
  thread_exit ();
c0020735:	e8 1d 08 00 00       	call   c0020f57 <thread_exit>
  argv[argc] = NULL;
c002073a:	c7 04 bd 20 69 03 c0 	movl   $0x0,-0x3ffc96e0(,%edi,4)
c0020741:	00 00 00 00 
  printf ("Kernel command line:");
c0020745:	83 ec 0c             	sub    $0xc,%esp
c0020748:	68 29 ce 02 c0       	push   $0xc002ce29
c002074d:	e8 0f 56 00 00       	call   c0025d61 <printf>
c0020752:	83 c4 10             	add    $0x10,%esp
  printf ("\n");
c0020755:	83 ec 0c             	sub    $0xc,%esp
c0020758:	6a 0a                	push   $0xa
c002075a:	e8 6a 8b 00 00       	call   c00292c9 <putchar>
  for (; *argv != NULL && **argv == '-'; argv++)
c002075f:	a1 20 69 03 c0       	mov    0xc0036920,%eax
c0020764:	83 c4 10             	add    $0x10,%esp
c0020767:	85 c0                	test   %eax,%eax
c0020769:	0f 84 39 fc ff ff    	je     c00203a8 <pintos_init+0x215>
c002076f:	80 38 2d             	cmpb   $0x2d,(%eax)
c0020772:	0f 85 b1 fc ff ff    	jne    c0020429 <pintos_init+0x296>
c0020778:	bd 20 69 03 c0       	mov    $0xc0036920,%ebp
      char *name = strtok_r (*argv, "=", &save_ptr);
c002077d:	8d 5c 24 20          	lea    0x20(%esp),%ebx
c0020781:	e9 29 fb ff ff       	jmp    c00202af <pintos_init+0x11c>

c0020786 <alloc_frame>:

/* Allocates a SIZE-byte frame at the top of thread T's stack and
   returns a pointer to the frame's base. */
static void *
alloc_frame (struct thread *t, size_t size) 
{
c0020786:	83 ec 0c             	sub    $0xc,%esp
  return t != NULL && t->magic == THREAD_MAGIC;
c0020789:	85 c0                	test   %eax,%eax
c002078b:	74 09                	je     c0020796 <alloc_frame+0x10>
c002078d:	81 78 40 4b bf 6a cd 	cmpl   $0xcd6abf4b,0x40(%eax)
c0020794:	74 42                	je     c00207d8 <alloc_frame+0x52>
  /* Stack data is always allocated in word-size units. */
  ASSERT (is_thread (t));
c0020796:	83 ec 0c             	sub    $0xc,%esp
c0020799:	68 05 d1 02 c0       	push   $0xc002d105
c002079e:	68 9f cd 02 c0       	push   $0xc002cd9f
c00207a3:	68 3c b7 02 c0       	push   $0xc002b73c
c00207a8:	68 13 02 00 00       	push   $0x213
c00207ad:	68 ee d0 02 c0       	push   $0xc002d0ee
c00207b2:	e8 58 70 00 00       	call   c002780f <debug_panic>
  ASSERT (size % sizeof (uint32_t) == 0);
c00207b7:	83 ec 0c             	sub    $0xc,%esp
c00207ba:	68 d0 d0 02 c0       	push   $0xc002d0d0
c00207bf:	68 9f cd 02 c0       	push   $0xc002cd9f
c00207c4:	68 3c b7 02 c0       	push   $0xc002b73c
c00207c9:	68 14 02 00 00       	push   $0x214
c00207ce:	68 ee d0 02 c0       	push   $0xc002d0ee
c00207d3:	e8 37 70 00 00       	call   c002780f <debug_panic>
c00207d8:	f6 c2 03             	test   $0x3,%dl
c00207db:	75 da                	jne    c00207b7 <alloc_frame+0x31>

  t->stack -= size;
c00207dd:	8b 48 18             	mov    0x18(%eax),%ecx
c00207e0:	29 d1                	sub    %edx,%ecx
c00207e2:	89 48 18             	mov    %ecx,0x18(%eax)
  return t->stack;
}
c00207e5:	89 c8                	mov    %ecx,%eax
c00207e7:	83 c4 0c             	add    $0xc,%esp
c00207ea:	c3                   	ret    

c00207eb <init_thread>:
{
c00207eb:	57                   	push   %edi
c00207ec:	56                   	push   %esi
c00207ed:	53                   	push   %ebx
  ASSERT (t != NULL);
c00207ee:	85 c0                	test   %eax,%eax
c00207f0:	74 73                	je     c0020865 <init_thread+0x7a>
c00207f2:	89 c3                	mov    %eax,%ebx
c00207f4:	89 ce                	mov    %ecx,%esi
  ASSERT (PRI_MIN <= priority && priority <= PRI_MAX);
c00207f6:	83 f9 3f             	cmp    $0x3f,%ecx
c00207f9:	0f 87 87 00 00 00    	ja     c0020886 <init_thread+0x9b>
  ASSERT (name != NULL);
c00207ff:	85 d2                	test   %edx,%edx
c0020801:	0f 84 a0 00 00 00    	je     c00208a7 <init_thread+0xbc>
  memset (t, 0, sizeof *t);
c0020807:	b9 11 00 00 00       	mov    $0x11,%ecx
c002080c:	b8 00 00 00 00       	mov    $0x0,%eax
c0020811:	89 df                	mov    %ebx,%edi
c0020813:	f3 ab                	rep stos %eax,%es:(%edi)
  t->status = THREAD_BLOCKED;
c0020815:	c7 43 04 02 00 00 00 	movl   $0x2,0x4(%ebx)
  strlcpy (t->name, name, sizeof t->name);
c002081c:	83 ec 04             	sub    $0x4,%esp
c002081f:	6a 10                	push   $0x10
c0020821:	52                   	push   %edx
c0020822:	8d 43 08             	lea    0x8(%ebx),%eax
c0020825:	50                   	push   %eax
c0020826:	e8 de 66 00 00       	call   c0026f09 <strlcpy>
  t->stack = (uint8_t *) t + PGSIZE;
c002082b:	8d 83 00 10 00 00    	lea    0x1000(%ebx),%eax
c0020831:	89 43 18             	mov    %eax,0x18(%ebx)
  t->priority = priority;
c0020834:	89 73 1c             	mov    %esi,0x1c(%ebx)
  t->magic = THREAD_MAGIC;
c0020837:	c7 43 40 4b bf 6a cd 	movl   $0xcd6abf4b,0x40(%ebx)
  old_level = intr_disable ();
c002083e:	e8 11 0a 00 00       	call   c0021254 <intr_disable>
c0020843:	89 c6                	mov    %eax,%esi
  list_push_back (&all_list, &t->allelem);
c0020845:	83 c4 08             	add    $0x8,%esp
c0020848:	83 c3 20             	add    $0x20,%ebx
c002084b:	53                   	push   %ebx
c002084c:	68 60 6a 03 c0       	push   $0xc0036a60
c0020851:	e8 fd 74 00 00       	call   c0027d53 <list_push_back>
  intr_set_level (old_level);
c0020856:	89 34 24             	mov    %esi,(%esp)
c0020859:	e8 fd 09 00 00       	call   c002125b <intr_set_level>
}
c002085e:	83 c4 10             	add    $0x10,%esp
c0020861:	5b                   	pop    %ebx
c0020862:	5e                   	pop    %esi
c0020863:	5f                   	pop    %edi
c0020864:	c3                   	ret    
  ASSERT (t != NULL);
c0020865:	83 ec 0c             	sub    $0xc,%esp
c0020868:	68 c7 e5 02 c0       	push   $0xc002e5c7
c002086d:	68 9f cd 02 c0       	push   $0xc002cd9f
c0020872:	68 68 b7 02 c0       	push   $0xc002b768
c0020877:	68 fd 01 00 00       	push   $0x1fd
c002087c:	68 ee d0 02 c0       	push   $0xc002d0ee
c0020881:	e8 89 6f 00 00       	call   c002780f <debug_panic>
  ASSERT (PRI_MIN <= priority && priority <= PRI_MAX);
c0020886:	83 ec 0c             	sub    $0xc,%esp
c0020889:	68 e0 d1 02 c0       	push   $0xc002d1e0
c002088e:	68 9f cd 02 c0       	push   $0xc002cd9f
c0020893:	68 68 b7 02 c0       	push   $0xc002b768
c0020898:	68 fe 01 00 00       	push   $0x1fe
c002089d:	68 ee d0 02 c0       	push   $0xc002d0ee
c00208a2:	e8 68 6f 00 00       	call   c002780f <debug_panic>
  ASSERT (name != NULL);
c00208a7:	83 ec 0c             	sub    $0xc,%esp
c00208aa:	68 13 d1 02 c0       	push   $0xc002d113
c00208af:	68 9f cd 02 c0       	push   $0xc002cd9f
c00208b4:	68 68 b7 02 c0       	push   $0xc002b768
c00208b9:	68 ff 01 00 00       	push   $0x1ff
c00208be:	68 ee d0 02 c0       	push   $0xc002d0ee
c00208c3:	e8 47 6f 00 00       	call   c002780f <debug_panic>

c00208c8 <thread_init>:
{
c00208c8:	56                   	push   %esi
c00208c9:	53                   	push   %ebx
c00208ca:	83 ec 04             	sub    $0x4,%esp
  ASSERT (intr_get_level () == INTR_OFF);
c00208cd:	e8 45 09 00 00       	call   c0021217 <intr_get_level>
c00208d2:	85 c0                	test   %eax,%eax
c00208d4:	0f 85 87 00 00 00    	jne    c0020961 <thread_init+0x99>
  lock_init (&tid_lock);
c00208da:	83 ec 0c             	sub    $0xc,%esp
c00208dd:	68 40 6a 03 c0       	push   $0xc0036a40
c00208e2:	e8 ce 1b 00 00       	call   c00224b5 <lock_init>
  list_init (&ready_list);
c00208e7:	c7 04 24 80 6a 03 c0 	movl   $0xc0036a80,(%esp)
c00208ee:	e8 c3 6f 00 00       	call   c00278b6 <list_init>
  list_init (&sleep_list);
c00208f3:	c7 04 24 70 6a 03 c0 	movl   $0xc0036a70,(%esp)
c00208fa:	e8 b7 6f 00 00       	call   c00278b6 <list_init>
  list_init (&all_list);
c00208ff:	c7 04 24 60 6a 03 c0 	movl   $0xc0036a60,(%esp)
c0020906:	e8 ab 6f 00 00       	call   c00278b6 <list_init>
  asm ("mov %%esp, %0" : "=g" (esp));
c002090b:	89 e0                	mov    %esp,%eax
  return (void *) ((uintptr_t) va & ~PGMASK);
c002090d:	25 00 f0 ff ff       	and    $0xfffff000,%eax
  initial_thread = running_thread ();
c0020912:	a3 58 6a 03 c0       	mov    %eax,0xc0036a58
  init_thread (initial_thread, "main", PRI_DEFAULT);
c0020917:	b9 1f 00 00 00       	mov    $0x1f,%ecx
c002091c:	ba 3e d1 02 c0       	mov    $0xc002d13e,%edx
c0020921:	e8 c5 fe ff ff       	call   c00207eb <init_thread>
  initial_thread->status = THREAD_RUNNING;
c0020926:	8b 1d 58 6a 03 c0    	mov    0xc0036a58,%ebx
c002092c:	c7 43 04 00 00 00 00 	movl   $0x0,0x4(%ebx)
allocate_tid (void) 
{
  static tid_t next_tid = 1;
  tid_t tid;

  lock_acquire (&tid_lock);
c0020933:	c7 04 24 40 6a 03 c0 	movl   $0xc0036a40,(%esp)
c002093a:	e8 f8 1b 00 00       	call   c0022537 <lock_acquire>
  tid = next_tid++;
c002093f:	8b 35 c4 64 03 c0    	mov    0xc00364c4,%esi
c0020945:	8d 46 01             	lea    0x1(%esi),%eax
c0020948:	a3 c4 64 03 c0       	mov    %eax,0xc00364c4
  lock_release (&tid_lock);
c002094d:	c7 04 24 40 6a 03 c0 	movl   $0xc0036a40,(%esp)
c0020954:	e8 03 1d 00 00       	call   c002265c <lock_release>
  initial_thread->tid = allocate_tid ();
c0020959:	89 33                	mov    %esi,(%ebx)
}
c002095b:	83 c4 14             	add    $0x14,%esp
c002095e:	5b                   	pop    %ebx
c002095f:	5e                   	pop    %esi
c0020960:	c3                   	ret    
  ASSERT (intr_get_level () == INTR_OFF);
c0020961:	83 ec 0c             	sub    $0xc,%esp
c0020964:	68 20 d1 02 c0       	push   $0xc002d120
c0020969:	68 9f cd 02 c0       	push   $0xc002cd9f
c002096e:	68 74 b7 02 c0       	push   $0xc002b774
c0020973:	6a 5e                	push   $0x5e
c0020975:	68 ee d0 02 c0       	push   $0xc002d0ee
c002097a:	e8 90 6e 00 00       	call   c002780f <debug_panic>

c002097f <thread_print_stats>:
{
c002097f:	83 ec 10             	sub    $0x10,%esp
  printf ("Thread: %lld idle ticks, %lld kernel ticks, %lld user ticks\n",
c0020982:	6a 00                	push   $0x0
c0020984:	6a 00                	push   $0x0
c0020986:	ff 35 34 6a 03 c0    	pushl  0xc0036a34
c002098c:	ff 35 30 6a 03 c0    	pushl  0xc0036a30
c0020992:	ff 35 3c 6a 03 c0    	pushl  0xc0036a3c
c0020998:	ff 35 38 6a 03 c0    	pushl  0xc0036a38
c002099e:	68 0c d2 02 c0       	push   $0xc002d20c
c00209a3:	e8 b9 53 00 00       	call   c0025d61 <printf>
}
c00209a8:	83 c4 2c             	add    $0x2c,%esp
c00209ab:	c3                   	ret    

c00209ac <thread_unblock>:
{
c00209ac:	56                   	push   %esi
c00209ad:	53                   	push   %ebx
c00209ae:	83 ec 04             	sub    $0x4,%esp
c00209b1:	8b 5c 24 10          	mov    0x10(%esp),%ebx
  return t != NULL && t->magic == THREAD_MAGIC;
c00209b5:	85 db                	test   %ebx,%ebx
c00209b7:	74 09                	je     c00209c2 <thread_unblock+0x16>
c00209b9:	81 7b 40 4b bf 6a cd 	cmpl   $0xcd6abf4b,0x40(%ebx)
c00209c0:	74 42                	je     c0020a04 <thread_unblock+0x58>
  ASSERT (is_thread (t));
c00209c2:	83 ec 0c             	sub    $0xc,%esp
c00209c5:	68 05 d1 02 c0       	push   $0xc002d105
c00209ca:	68 9f cd 02 c0       	push   $0xc002cd9f
c00209cf:	68 10 b7 02 c0       	push   $0xc002b710
c00209d4:	68 f2 00 00 00       	push   $0xf2
c00209d9:	68 ee d0 02 c0       	push   $0xc002d0ee
c00209de:	e8 2c 6e 00 00       	call   c002780f <debug_panic>
  ASSERT (t->status == THREAD_BLOCKED);
c00209e3:	83 ec 0c             	sub    $0xc,%esp
c00209e6:	68 43 d1 02 c0       	push   $0xc002d143
c00209eb:	68 9f cd 02 c0       	push   $0xc002cd9f
c00209f0:	68 10 b7 02 c0       	push   $0xc002b710
c00209f5:	68 f5 00 00 00       	push   $0xf5
c00209fa:	68 ee d0 02 c0       	push   $0xc002d0ee
c00209ff:	e8 0b 6e 00 00       	call   c002780f <debug_panic>
  old_level = intr_disable ();
c0020a04:	e8 4b 08 00 00       	call   c0021254 <intr_disable>
c0020a09:	89 c6                	mov    %eax,%esi
  ASSERT (t->status == THREAD_BLOCKED);
c0020a0b:	83 7b 04 02          	cmpl   $0x2,0x4(%ebx)
c0020a0f:	75 d2                	jne    c00209e3 <thread_unblock+0x37>
  list_push_back (&ready_list, &t->elem);
c0020a11:	83 ec 08             	sub    $0x8,%esp
c0020a14:	8d 43 38             	lea    0x38(%ebx),%eax
c0020a17:	50                   	push   %eax
c0020a18:	68 80 6a 03 c0       	push   $0xc0036a80
c0020a1d:	e8 31 73 00 00       	call   c0027d53 <list_push_back>
  t->status = THREAD_READY;
c0020a22:	c7 43 04 01 00 00 00 	movl   $0x1,0x4(%ebx)
  intr_set_level (old_level);
c0020a29:	89 34 24             	mov    %esi,(%esp)
c0020a2c:	e8 2a 08 00 00       	call   c002125b <intr_set_level>
}
c0020a31:	83 c4 10             	add    $0x10,%esp
c0020a34:	83 c4 04             	add    $0x4,%esp
c0020a37:	5b                   	pop    %ebx
c0020a38:	5e                   	pop    %esi
c0020a39:	c3                   	ret    

c0020a3a <thread_create>:
{
c0020a3a:	57                   	push   %edi
c0020a3b:	56                   	push   %esi
c0020a3c:	53                   	push   %ebx
c0020a3d:	8b 7c 24 18          	mov    0x18(%esp),%edi
  ASSERT (function != NULL);
c0020a41:	85 ff                	test   %edi,%edi
c0020a43:	0f 84 a6 00 00 00    	je     c0020aef <thread_create+0xb5>
  t = palloc_get_page (PAL_ZERO);
c0020a49:	83 ec 0c             	sub    $0xc,%esp
c0020a4c:	6a 02                	push   $0x2
c0020a4e:	e8 bd 20 00 00       	call   c0022b10 <palloc_get_page>
c0020a53:	89 c3                	mov    %eax,%ebx
  if (t == NULL)
c0020a55:	83 c4 10             	add    $0x10,%esp
c0020a58:	85 c0                	test   %eax,%eax
c0020a5a:	0f 84 b0 00 00 00    	je     c0020b10 <thread_create+0xd6>
  init_thread (t, name, priority);
c0020a60:	8b 4c 24 14          	mov    0x14(%esp),%ecx
c0020a64:	8b 54 24 10          	mov    0x10(%esp),%edx
c0020a68:	e8 7e fd ff ff       	call   c00207eb <init_thread>
  lock_acquire (&tid_lock);
c0020a6d:	83 ec 0c             	sub    $0xc,%esp
c0020a70:	68 40 6a 03 c0       	push   $0xc0036a40
c0020a75:	e8 bd 1a 00 00       	call   c0022537 <lock_acquire>
  tid = next_tid++;
c0020a7a:	8b 35 c4 64 03 c0    	mov    0xc00364c4,%esi
c0020a80:	8d 46 01             	lea    0x1(%esi),%eax
c0020a83:	a3 c4 64 03 c0       	mov    %eax,0xc00364c4
  lock_release (&tid_lock);
c0020a88:	c7 04 24 40 6a 03 c0 	movl   $0xc0036a40,(%esp)
c0020a8f:	e8 c8 1b 00 00       	call   c002265c <lock_release>
  tid = t->tid = allocate_tid ();
c0020a94:	89 33                	mov    %esi,(%ebx)
  kf = alloc_frame (t, sizeof *kf);
c0020a96:	ba 0c 00 00 00       	mov    $0xc,%edx
c0020a9b:	89 d8                	mov    %ebx,%eax
c0020a9d:	e8 e4 fc ff ff       	call   c0020786 <alloc_frame>
  kf->eip = NULL;
c0020aa2:	c7 00 00 00 00 00    	movl   $0x0,(%eax)
  kf->function = function;
c0020aa8:	89 78 04             	mov    %edi,0x4(%eax)
  kf->aux = aux;
c0020aab:	8b 54 24 2c          	mov    0x2c(%esp),%edx
c0020aaf:	89 50 08             	mov    %edx,0x8(%eax)
  ef = alloc_frame (t, sizeof *ef);
c0020ab2:	ba 04 00 00 00       	mov    $0x4,%edx
c0020ab7:	89 d8                	mov    %ebx,%eax
c0020ab9:	e8 c8 fc ff ff       	call   c0020786 <alloc_frame>
  ef->eip = (void (*) (void)) kernel_thread;
c0020abe:	c7 00 c4 0f 02 c0    	movl   $0xc0020fc4,(%eax)
  sf = alloc_frame (t, sizeof *sf);
c0020ac4:	ba 1c 00 00 00       	mov    $0x1c,%edx
c0020ac9:	89 d8                	mov    %ebx,%eax
c0020acb:	e8 b6 fc ff ff       	call   c0020786 <alloc_frame>
  sf->eip = switch_entry;
c0020ad0:	c7 40 10 e3 10 02 c0 	movl   $0xc00210e3,0x10(%eax)
  sf->ebp = 0;
c0020ad7:	c7 40 08 00 00 00 00 	movl   $0x0,0x8(%eax)
  thread_unblock (t);
c0020ade:	89 1c 24             	mov    %ebx,(%esp)
c0020ae1:	e8 c6 fe ff ff       	call   c00209ac <thread_unblock>
  return tid;
c0020ae6:	83 c4 10             	add    $0x10,%esp
}
c0020ae9:	89 f0                	mov    %esi,%eax
c0020aeb:	5b                   	pop    %ebx
c0020aec:	5e                   	pop    %esi
c0020aed:	5f                   	pop    %edi
c0020aee:	c3                   	ret    
  ASSERT (function != NULL);
c0020aef:	83 ec 0c             	sub    $0xc,%esp
c0020af2:	68 5f d1 02 c0       	push   $0xc002d15f
c0020af7:	68 9f cd 02 c0       	push   $0xc002cd9f
c0020afc:	68 58 b7 02 c0       	push   $0xc002b758
c0020b01:	68 b4 00 00 00       	push   $0xb4
c0020b06:	68 ee d0 02 c0       	push   $0xc002d0ee
c0020b0b:	e8 ff 6c 00 00       	call   c002780f <debug_panic>
    return TID_ERROR;
c0020b10:	be ff ff ff ff       	mov    $0xffffffff,%esi
c0020b15:	eb d2                	jmp    c0020ae9 <thread_create+0xaf>

c0020b17 <thread_start>:
{
c0020b17:	53                   	push   %ebx
c0020b18:	83 ec 30             	sub    $0x30,%esp
  sema_init (&idle_started, 0);
c0020b1b:	6a 00                	push   $0x0
c0020b1d:	8d 5c 24 18          	lea    0x18(%esp),%ebx
c0020b21:	53                   	push   %ebx
c0020b22:	e8 5b 17 00 00       	call   c0022282 <sema_init>
  thread_create ("idle", PRI_MIN, idle, &idle_started);
c0020b27:	53                   	push   %ebx
c0020b28:	68 2d 0f 02 c0       	push   $0xc0020f2d
c0020b2d:	6a 00                	push   $0x0
c0020b2f:	68 70 d1 02 c0       	push   $0xc002d170
c0020b34:	e8 01 ff ff ff       	call   c0020a3a <thread_create>
  intr_enable ();
c0020b39:	83 c4 20             	add    $0x20,%esp
c0020b3c:	e8 df 06 00 00       	call   c0021220 <intr_enable>
  sema_down (&idle_started);
c0020b41:	83 ec 0c             	sub    $0xc,%esp
c0020b44:	53                   	push   %ebx
c0020b45:	e8 77 17 00 00       	call   c00222c1 <sema_down>
}
c0020b4a:	83 c4 38             	add    $0x38,%esp
c0020b4d:	5b                   	pop    %ebx
c0020b4e:	c3                   	ret    

c0020b4f <thread_current>:
{
c0020b4f:	83 ec 0c             	sub    $0xc,%esp
  asm ("mov %%esp, %0" : "=g" (esp));
c0020b52:	89 e0                	mov    %esp,%eax
  return t != NULL && t->magic == THREAD_MAGIC;
c0020b54:	25 00 f0 ff ff       	and    $0xfffff000,%eax
c0020b59:	74 09                	je     c0020b64 <thread_current+0x15>
c0020b5b:	81 78 40 4b bf 6a cd 	cmpl   $0xcd6abf4b,0x40(%eax)
c0020b62:	74 42                	je     c0020ba6 <thread_current+0x57>
  ASSERT (is_thread (t));
c0020b64:	83 ec 0c             	sub    $0xc,%esp
c0020b67:	68 05 d1 02 c0       	push   $0xc002d105
c0020b6c:	68 9f cd 02 c0       	push   $0xc002cd9f
c0020b71:	68 00 b7 02 c0       	push   $0xc002b700
c0020b76:	68 0f 01 00 00       	push   $0x10f
c0020b7b:	68 ee d0 02 c0       	push   $0xc002d0ee
c0020b80:	e8 8a 6c 00 00       	call   c002780f <debug_panic>
  ASSERT (t->status == THREAD_RUNNING);
c0020b85:	83 ec 0c             	sub    $0xc,%esp
c0020b88:	68 75 d1 02 c0       	push   $0xc002d175
c0020b8d:	68 9f cd 02 c0       	push   $0xc002cd9f
c0020b92:	68 00 b7 02 c0       	push   $0xc002b700
c0020b97:	68 10 01 00 00       	push   $0x110
c0020b9c:	68 ee d0 02 c0       	push   $0xc002d0ee
c0020ba1:	e8 69 6c 00 00       	call   c002780f <debug_panic>
c0020ba6:	83 78 04 00          	cmpl   $0x0,0x4(%eax)
c0020baa:	75 d9                	jne    c0020b85 <thread_current+0x36>
}
c0020bac:	83 c4 0c             	add    $0xc,%esp
c0020baf:	c3                   	ret    

c0020bb0 <thread_tick>:
{
c0020bb0:	83 ec 0c             	sub    $0xc,%esp
  struct thread *t = thread_current ();
c0020bb3:	e8 97 ff ff ff       	call   c0020b4f <thread_current>
  if (t == idle_thread)
c0020bb8:	3b 05 5c 6a 03 c0    	cmp    0xc0036a5c,%eax
c0020bbe:	74 22                	je     c0020be2 <thread_tick+0x32>
    kernel_ticks++;
c0020bc0:	83 05 30 6a 03 c0 01 	addl   $0x1,0xc0036a30
c0020bc7:	83 15 34 6a 03 c0 00 	adcl   $0x0,0xc0036a34
  if (++thread_ticks >= TIME_SLICE)
c0020bce:	a1 28 6a 03 c0       	mov    0xc0036a28,%eax
c0020bd3:	40                   	inc    %eax
c0020bd4:	a3 28 6a 03 c0       	mov    %eax,0xc0036a28
c0020bd9:	83 f8 03             	cmp    $0x3,%eax
c0020bdc:	77 14                	ja     c0020bf2 <thread_tick+0x42>
}
c0020bde:	83 c4 0c             	add    $0xc,%esp
c0020be1:	c3                   	ret    
    idle_ticks++;
c0020be2:	83 05 38 6a 03 c0 01 	addl   $0x1,0xc0036a38
c0020be9:	83 15 3c 6a 03 c0 00 	adcl   $0x0,0xc0036a3c
c0020bf0:	eb dc                	jmp    c0020bce <thread_tick+0x1e>
    intr_yield_on_return ();
c0020bf2:	e8 84 08 00 00       	call   c002147b <intr_yield_on_return>
}
c0020bf7:	eb e5                	jmp    c0020bde <thread_tick+0x2e>

c0020bf9 <thread_name>:
{
c0020bf9:	83 ec 0c             	sub    $0xc,%esp
  return thread_current ()->name;
c0020bfc:	e8 4e ff ff ff       	call   c0020b4f <thread_current>
c0020c01:	83 c0 08             	add    $0x8,%eax
}
c0020c04:	83 c4 0c             	add    $0xc,%esp
c0020c07:	c3                   	ret    

c0020c08 <thread_tid>:
{
c0020c08:	83 ec 0c             	sub    $0xc,%esp
  return thread_current ()->tid;
c0020c0b:	e8 3f ff ff ff       	call   c0020b4f <thread_current>
c0020c10:	8b 00                	mov    (%eax),%eax
}
c0020c12:	83 c4 0c             	add    $0xc,%esp
c0020c15:	c3                   	ret    

c0020c16 <sleep_to_ready>:
void sleep_to_ready(int64_t tick){
c0020c16:	53                   	push   %ebx
c0020c17:	83 ec 14             	sub    $0x14,%esp
  e = list_begin(&sleep_list);
c0020c1a:	68 70 6a 03 c0       	push   $0xc0036a70
c0020c1f:	e8 d5 6c 00 00       	call   c00278f9 <list_begin>
c0020c24:	89 c3                	mov    %eax,%ebx
  while (e != list_end(&sleep_list))
c0020c26:	83 c4 10             	add    $0x10,%esp
c0020c29:	eb 2e                	jmp    c0020c59 <sleep_to_ready+0x43>
    if (t->wakeup_tick > 0)
c0020c2b:	83 f8 00             	cmp    $0x0,%eax
c0020c2e:	77 4b                	ja     c0020c7b <sleep_to_ready+0x65>
      thread_unblock(t);
c0020c30:	83 ec 0c             	sub    $0xc,%esp
    struct thread *t = list_entry(e, struct thread, sleepelem);
c0020c33:	8d 43 d0             	lea    -0x30(%ebx),%eax
      thread_unblock(t);
c0020c36:	50                   	push   %eax
c0020c37:	e8 70 fd ff ff       	call   c00209ac <thread_unblock>
      e = list_remove(e);
c0020c3c:	89 1c 24             	mov    %ebx,(%esp)
c0020c3f:	e8 2c 71 00 00       	call   c0027d70 <list_remove>
c0020c44:	89 c3                	mov    %eax,%ebx
c0020c46:	83 c4 10             	add    $0x10,%esp
c0020c49:	eb 0e                	jmp    c0020c59 <sleep_to_ready+0x43>
    else e = list_next(e);
c0020c4b:	83 ec 0c             	sub    $0xc,%esp
c0020c4e:	53                   	push   %ebx
c0020c4f:	e8 d5 6c 00 00       	call   c0027929 <list_next>
c0020c54:	89 c3                	mov    %eax,%ebx
c0020c56:	83 c4 10             	add    $0x10,%esp
  while (e != list_end(&sleep_list))
c0020c59:	83 ec 0c             	sub    $0xc,%esp
c0020c5c:	68 70 6a 03 c0       	push   $0xc0036a70
c0020c61:	e8 0b 6d 00 00       	call   c0027971 <list_end>
c0020c66:	83 c4 10             	add    $0x10,%esp
c0020c69:	39 c3                	cmp    %eax,%ebx
c0020c6b:	74 29                	je     c0020c96 <sleep_to_ready+0x80>
    if (t->wakeup_tick > 0)
c0020c6d:	8b 43 f8             	mov    -0x8(%ebx),%eax
c0020c70:	8b 53 fc             	mov    -0x4(%ebx),%edx
c0020c73:	85 d2                	test   %edx,%edx
c0020c75:	78 b9                	js     c0020c30 <sleep_to_ready+0x1a>
c0020c77:	85 d2                	test   %edx,%edx
c0020c79:	7e b0                	jle    c0020c2b <sleep_to_ready+0x15>
      t->wakeup_tick--;
c0020c7b:	83 c0 ff             	add    $0xffffffff,%eax
c0020c7e:	83 d2 ff             	adc    $0xffffffff,%edx
c0020c81:	89 43 f8             	mov    %eax,-0x8(%ebx)
c0020c84:	89 53 fc             	mov    %edx,-0x4(%ebx)
    if (t->wakeup_tick <= 0)
c0020c87:	85 d2                	test   %edx,%edx
c0020c89:	7f c0                	jg     c0020c4b <sleep_to_ready+0x35>
c0020c8b:	85 d2                	test   %edx,%edx
c0020c8d:	78 a1                	js     c0020c30 <sleep_to_ready+0x1a>
c0020c8f:	83 f8 00             	cmp    $0x0,%eax
c0020c92:	77 b7                	ja     c0020c4b <sleep_to_ready+0x35>
c0020c94:	eb 9a                	jmp    c0020c30 <sleep_to_ready+0x1a>
}
c0020c96:	83 c4 08             	add    $0x8,%esp
c0020c99:	5b                   	pop    %ebx
c0020c9a:	c3                   	ret    

c0020c9b <thread_foreach>:
{
c0020c9b:	57                   	push   %edi
c0020c9c:	56                   	push   %esi
c0020c9d:	53                   	push   %ebx
c0020c9e:	8b 74 24 10          	mov    0x10(%esp),%esi
c0020ca2:	8b 7c 24 14          	mov    0x14(%esp),%edi
  ASSERT (intr_get_level () == INTR_OFF);
c0020ca6:	e8 6c 05 00 00       	call   c0021217 <intr_get_level>
c0020cab:	85 c0                	test   %eax,%eax
c0020cad:	75 14                	jne    c0020cc3 <thread_foreach+0x28>
  for (e = list_begin (&all_list); e != list_end (&all_list);
c0020caf:	83 ec 0c             	sub    $0xc,%esp
c0020cb2:	68 60 6a 03 c0       	push   $0xc0036a60
c0020cb7:	e8 3d 6c 00 00       	call   c00278f9 <list_begin>
c0020cbc:	89 c3                	mov    %eax,%ebx
c0020cbe:	83 c4 10             	add    $0x10,%esp
c0020cc1:	eb 38                	jmp    c0020cfb <thread_foreach+0x60>
  ASSERT (intr_get_level () == INTR_OFF);
c0020cc3:	83 ec 0c             	sub    $0xc,%esp
c0020cc6:	68 20 d1 02 c0       	push   $0xc002d120
c0020ccb:	68 9f cd 02 c0       	push   $0xc002cd9f
c0020cd0:	68 d4 b6 02 c0       	push   $0xc002b6d4
c0020cd5:	68 79 01 00 00       	push   $0x179
c0020cda:	68 ee d0 02 c0       	push   $0xc002d0ee
c0020cdf:	e8 2b 6b 00 00       	call   c002780f <debug_panic>
      func (t, aux);
c0020ce4:	83 ec 08             	sub    $0x8,%esp
c0020ce7:	57                   	push   %edi
      struct thread *t = list_entry (e, struct thread, allelem);
c0020ce8:	8d 43 e0             	lea    -0x20(%ebx),%eax
      func (t, aux);
c0020ceb:	50                   	push   %eax
c0020cec:	ff d6                	call   *%esi
       e = list_next (e))
c0020cee:	89 1c 24             	mov    %ebx,(%esp)
c0020cf1:	e8 33 6c 00 00       	call   c0027929 <list_next>
c0020cf6:	89 c3                	mov    %eax,%ebx
c0020cf8:	83 c4 10             	add    $0x10,%esp
  for (e = list_begin (&all_list); e != list_end (&all_list);
c0020cfb:	83 ec 0c             	sub    $0xc,%esp
c0020cfe:	68 60 6a 03 c0       	push   $0xc0036a60
c0020d03:	e8 69 6c 00 00       	call   c0027971 <list_end>
c0020d08:	83 c4 10             	add    $0x10,%esp
c0020d0b:	39 c3                	cmp    %eax,%ebx
c0020d0d:	75 d5                	jne    c0020ce4 <thread_foreach+0x49>
}
c0020d0f:	5b                   	pop    %ebx
c0020d10:	5e                   	pop    %esi
c0020d11:	5f                   	pop    %edi
c0020d12:	c3                   	ret    

c0020d13 <thread_set_priority>:
{
c0020d13:	83 ec 0c             	sub    $0xc,%esp
  thread_current ()->priority = new_priority;
c0020d16:	e8 34 fe ff ff       	call   c0020b4f <thread_current>
c0020d1b:	8b 54 24 10          	mov    0x10(%esp),%edx
c0020d1f:	89 50 1c             	mov    %edx,0x1c(%eax)
}
c0020d22:	83 c4 0c             	add    $0xc,%esp
c0020d25:	c3                   	ret    

c0020d26 <thread_get_priority>:
{
c0020d26:	83 ec 0c             	sub    $0xc,%esp
  return thread_current ()->priority;
c0020d29:	e8 21 fe ff ff       	call   c0020b4f <thread_current>
c0020d2e:	8b 40 1c             	mov    0x1c(%eax),%eax
}
c0020d31:	83 c4 0c             	add    $0xc,%esp
c0020d34:	c3                   	ret    

c0020d35 <thread_set_nice>:
{
c0020d35:	c3                   	ret    

c0020d36 <thread_get_nice>:
}
c0020d36:	b8 00 00 00 00       	mov    $0x0,%eax
c0020d3b:	c3                   	ret    

c0020d3c <thread_get_load_avg>:
}
c0020d3c:	b8 00 00 00 00       	mov    $0x0,%eax
c0020d41:	c3                   	ret    

c0020d42 <thread_get_recent_cpu>:
}
c0020d42:	b8 00 00 00 00       	mov    $0x0,%eax
c0020d47:	c3                   	ret    

c0020d48 <thread_schedule_tail>:
{
c0020d48:	56                   	push   %esi
c0020d49:	53                   	push   %ebx
c0020d4a:	83 ec 04             	sub    $0x4,%esp
c0020d4d:	8b 74 24 10          	mov    0x10(%esp),%esi
  asm ("mov %%esp, %0" : "=g" (esp));
c0020d51:	89 e3                	mov    %esp,%ebx
c0020d53:	81 e3 00 f0 ff ff    	and    $0xfffff000,%ebx
  ASSERT (intr_get_level () == INTR_OFF);
c0020d59:	e8 b9 04 00 00       	call   c0021217 <intr_get_level>
c0020d5e:	85 c0                	test   %eax,%eax
c0020d60:	75 21                	jne    c0020d83 <thread_schedule_tail+0x3b>
  cur->status = THREAD_RUNNING;
c0020d62:	c7 43 04 00 00 00 00 	movl   $0x0,0x4(%ebx)
  thread_ticks = 0;
c0020d69:	c7 05 28 6a 03 c0 00 	movl   $0x0,0xc0036a28
c0020d70:	00 00 00 
  if (prev != NULL && prev->status == THREAD_DYING && prev != initial_thread) 
c0020d73:	85 f6                	test   %esi,%esi
c0020d75:	74 06                	je     c0020d7d <thread_schedule_tail+0x35>
c0020d77:	83 7e 04 03          	cmpl   $0x3,0x4(%esi)
c0020d7b:	74 27                	je     c0020da4 <thread_schedule_tail+0x5c>
}
c0020d7d:	83 c4 04             	add    $0x4,%esp
c0020d80:	5b                   	pop    %ebx
c0020d81:	5e                   	pop    %esi
c0020d82:	c3                   	ret    
  ASSERT (intr_get_level () == INTR_OFF);
c0020d83:	83 ec 0c             	sub    $0xc,%esp
c0020d86:	68 20 d1 02 c0       	push   $0xc002d120
c0020d8b:	68 9f cd 02 c0       	push   $0xc002cd9f
c0020d90:	68 bc b6 02 c0       	push   $0xc002b6bc
c0020d95:	68 3d 02 00 00       	push   $0x23d
c0020d9a:	68 ee d0 02 c0       	push   $0xc002d0ee
c0020d9f:	e8 6b 6a 00 00       	call   c002780f <debug_panic>
  if (prev != NULL && prev->status == THREAD_DYING && prev != initial_thread) 
c0020da4:	3b 35 58 6a 03 c0    	cmp    0xc0036a58,%esi
c0020daa:	74 d1                	je     c0020d7d <thread_schedule_tail+0x35>
      ASSERT (prev != cur);
c0020dac:	39 de                	cmp    %ebx,%esi
c0020dae:	74 0e                	je     c0020dbe <thread_schedule_tail+0x76>
      palloc_free_page (prev);
c0020db0:	83 ec 0c             	sub    $0xc,%esp
c0020db3:	56                   	push   %esi
c0020db4:	e8 81 1e 00 00       	call   c0022c3a <palloc_free_page>
c0020db9:	83 c4 10             	add    $0x10,%esp
}
c0020dbc:	eb bf                	jmp    c0020d7d <thread_schedule_tail+0x35>
      ASSERT (prev != cur);
c0020dbe:	83 ec 0c             	sub    $0xc,%esp
c0020dc1:	68 91 d1 02 c0       	push   $0xc002d191
c0020dc6:	68 9f cd 02 c0       	push   $0xc002cd9f
c0020dcb:	68 bc b6 02 c0       	push   $0xc002b6bc
c0020dd0:	68 51 02 00 00       	push   $0x251
c0020dd5:	68 ee d0 02 c0       	push   $0xc002d0ee
c0020dda:	e8 30 6a 00 00       	call   c002780f <debug_panic>

c0020ddf <schedule>:
{
c0020ddf:	56                   	push   %esi
c0020de0:	53                   	push   %ebx
c0020de1:	83 ec 10             	sub    $0x10,%esp
  asm ("mov %%esp, %0" : "=g" (esp));
c0020de4:	89 e3                	mov    %esp,%ebx
c0020de6:	81 e3 00 f0 ff ff    	and    $0xfffff000,%ebx
  if (list_empty (&ready_list))
c0020dec:	68 80 6a 03 c0       	push   $0xc0036a80
c0020df1:	e8 05 70 00 00       	call   c0027dfb <list_empty>
c0020df6:	83 c4 10             	add    $0x10,%esp
c0020df9:	84 c0                	test   %al,%al
c0020dfb:	74 43                	je     c0020e40 <schedule+0x61>
    return idle_thread;
c0020dfd:	8b 35 5c 6a 03 c0    	mov    0xc0036a5c,%esi
  ASSERT (intr_get_level () == INTR_OFF);
c0020e03:	e8 0f 04 00 00       	call   c0021217 <intr_get_level>
c0020e08:	85 c0                	test   %eax,%eax
c0020e0a:	75 49                	jne    c0020e55 <schedule+0x76>
  ASSERT (cur->status != THREAD_RUNNING);
c0020e0c:	83 7b 04 00          	cmpl   $0x0,0x4(%ebx)
c0020e10:	74 64                	je     c0020e76 <schedule+0x97>
  return t != NULL && t->magic == THREAD_MAGIC;
c0020e12:	85 f6                	test   %esi,%esi
c0020e14:	74 09                	je     c0020e1f <schedule+0x40>
c0020e16:	81 7e 40 4b bf 6a cd 	cmpl   $0xcd6abf4b,0x40(%esi)
c0020e1d:	74 78                	je     c0020e97 <schedule+0xb8>
  ASSERT (is_thread (next));
c0020e1f:	83 ec 0c             	sub    $0xc,%esp
c0020e22:	68 bb d1 02 c0       	push   $0xc002d1bb
c0020e27:	68 9f cd 02 c0       	push   $0xc002cd9f
c0020e2c:	68 20 b7 02 c0       	push   $0xc002b720
c0020e31:	68 66 02 00 00       	push   $0x266
c0020e36:	68 ee d0 02 c0       	push   $0xc002d0ee
c0020e3b:	e8 cf 69 00 00       	call   c002780f <debug_panic>
    return list_entry (list_pop_front (&ready_list), struct thread, elem);
c0020e40:	83 ec 0c             	sub    $0xc,%esp
c0020e43:	68 80 6a 03 c0       	push   $0xc0036a80
c0020e48:	e8 10 70 00 00       	call   c0027e5d <list_pop_front>
c0020e4d:	8d 70 c8             	lea    -0x38(%eax),%esi
c0020e50:	83 c4 10             	add    $0x10,%esp
c0020e53:	eb ae                	jmp    c0020e03 <schedule+0x24>
  ASSERT (intr_get_level () == INTR_OFF);
c0020e55:	83 ec 0c             	sub    $0xc,%esp
c0020e58:	68 20 d1 02 c0       	push   $0xc002d120
c0020e5d:	68 9f cd 02 c0       	push   $0xc002cd9f
c0020e62:	68 20 b7 02 c0       	push   $0xc002b720
c0020e67:	68 64 02 00 00       	push   $0x264
c0020e6c:	68 ee d0 02 c0       	push   $0xc002d0ee
c0020e71:	e8 99 69 00 00       	call   c002780f <debug_panic>
  ASSERT (cur->status != THREAD_RUNNING);
c0020e76:	83 ec 0c             	sub    $0xc,%esp
c0020e79:	68 9d d1 02 c0       	push   $0xc002d19d
c0020e7e:	68 9f cd 02 c0       	push   $0xc002cd9f
c0020e83:	68 20 b7 02 c0       	push   $0xc002b720
c0020e88:	68 65 02 00 00       	push   $0x265
c0020e8d:	68 ee d0 02 c0       	push   $0xc002d0ee
c0020e92:	e8 78 69 00 00       	call   c002780f <debug_panic>
  if (cur != next)
c0020e97:	39 de                	cmp    %ebx,%esi
c0020e99:	74 1f                	je     c0020eba <schedule+0xdb>
    prev = switch_threads (cur, next);
c0020e9b:	83 ec 08             	sub    $0x8,%esp
c0020e9e:	56                   	push   %esi
c0020e9f:	53                   	push   %ebx
c0020ea0:	e8 21 02 00 00       	call   c00210c6 <switch_threads>
c0020ea5:	83 c4 10             	add    $0x10,%esp
  thread_schedule_tail (prev);
c0020ea8:	83 ec 0c             	sub    $0xc,%esp
c0020eab:	50                   	push   %eax
c0020eac:	e8 97 fe ff ff       	call   c0020d48 <thread_schedule_tail>
}
c0020eb1:	83 c4 10             	add    $0x10,%esp
c0020eb4:	83 c4 04             	add    $0x4,%esp
c0020eb7:	5b                   	pop    %ebx
c0020eb8:	5e                   	pop    %esi
c0020eb9:	c3                   	ret    
  struct thread *prev = NULL;
c0020eba:	b8 00 00 00 00       	mov    $0x0,%eax
c0020ebf:	eb e7                	jmp    c0020ea8 <schedule+0xc9>

c0020ec1 <thread_block>:
{
c0020ec1:	83 ec 0c             	sub    $0xc,%esp
  ASSERT (!intr_context ());
c0020ec4:	e8 ac 05 00 00       	call   c0021475 <intr_context>
c0020ec9:	84 c0                	test   %al,%al
c0020ecb:	75 1e                	jne    c0020eeb <thread_block+0x2a>
  ASSERT (intr_get_level () == INTR_OFF);
c0020ecd:	e8 45 03 00 00       	call   c0021217 <intr_get_level>
c0020ed2:	85 c0                	test   %eax,%eax
c0020ed4:	75 36                	jne    c0020f0c <thread_block+0x4b>
  thread_current ()->status = THREAD_BLOCKED;
c0020ed6:	e8 74 fc ff ff       	call   c0020b4f <thread_current>
c0020edb:	c7 40 04 02 00 00 00 	movl   $0x2,0x4(%eax)
  schedule ();
c0020ee2:	e8 f8 fe ff ff       	call   c0020ddf <schedule>
}
c0020ee7:	83 c4 0c             	add    $0xc,%esp
c0020eea:	c3                   	ret    
  ASSERT (!intr_context ());
c0020eeb:	83 ec 0c             	sub    $0xc,%esp
c0020eee:	68 cc d1 02 c0       	push   $0xc002d1cc
c0020ef3:	68 9f cd 02 c0       	push   $0xc002cd9f
c0020ef8:	68 2c b7 02 c0       	push   $0xc002b72c
c0020efd:	68 dd 00 00 00       	push   $0xdd
c0020f02:	68 ee d0 02 c0       	push   $0xc002d0ee
c0020f07:	e8 03 69 00 00       	call   c002780f <debug_panic>
  ASSERT (intr_get_level () == INTR_OFF);
c0020f0c:	83 ec 0c             	sub    $0xc,%esp
c0020f0f:	68 20 d1 02 c0       	push   $0xc002d120
c0020f14:	68 9f cd 02 c0       	push   $0xc002cd9f
c0020f19:	68 2c b7 02 c0       	push   $0xc002b72c
c0020f1e:	68 de 00 00 00       	push   $0xde
c0020f23:	68 ee d0 02 c0       	push   $0xc002d0ee
c0020f28:	e8 e2 68 00 00       	call   c002780f <debug_panic>

c0020f2d <idle>:
{
c0020f2d:	83 ec 0c             	sub    $0xc,%esp
  idle_thread = thread_current ();
c0020f30:	e8 1a fc ff ff       	call   c0020b4f <thread_current>
c0020f35:	a3 5c 6a 03 c0       	mov    %eax,0xc0036a5c
  sema_up (idle_started);
c0020f3a:	83 ec 0c             	sub    $0xc,%esp
c0020f3d:	ff 74 24 1c          	pushl  0x1c(%esp)
c0020f41:	e8 5c 14 00 00       	call   c00223a2 <sema_up>
c0020f46:	83 c4 10             	add    $0x10,%esp
      intr_disable ();
c0020f49:	e8 06 03 00 00       	call   c0021254 <intr_disable>
      thread_block ();
c0020f4e:	e8 6e ff ff ff       	call   c0020ec1 <thread_block>
      asm volatile ("sti; hlt" : : : "memory");
c0020f53:	fb                   	sti    
c0020f54:	f4                   	hlt    
c0020f55:	eb f2                	jmp    c0020f49 <idle+0x1c>

c0020f57 <thread_exit>:
{
c0020f57:	83 ec 0c             	sub    $0xc,%esp
  ASSERT (!intr_context ());
c0020f5a:	e8 16 05 00 00       	call   c0021475 <intr_context>
c0020f5f:	84 c0                	test   %al,%al
c0020f61:	74 21                	je     c0020f84 <thread_exit+0x2d>
c0020f63:	83 ec 0c             	sub    $0xc,%esp
c0020f66:	68 cc d1 02 c0       	push   $0xc002d1cc
c0020f6b:	68 9f cd 02 c0       	push   $0xc002cd9f
c0020f70:	68 f4 b6 02 c0       	push   $0xc002b6f4
c0020f75:	68 21 01 00 00       	push   $0x121
c0020f7a:	68 ee d0 02 c0       	push   $0xc002d0ee
c0020f7f:	e8 8b 68 00 00       	call   c002780f <debug_panic>
  intr_disable ();
c0020f84:	e8 cb 02 00 00       	call   c0021254 <intr_disable>
  list_remove (&thread_current()->allelem);
c0020f89:	e8 c1 fb ff ff       	call   c0020b4f <thread_current>
c0020f8e:	83 ec 0c             	sub    $0xc,%esp
c0020f91:	83 c0 20             	add    $0x20,%eax
c0020f94:	50                   	push   %eax
c0020f95:	e8 d6 6d 00 00       	call   c0027d70 <list_remove>
  thread_current ()->status = THREAD_DYING;
c0020f9a:	e8 b0 fb ff ff       	call   c0020b4f <thread_current>
c0020f9f:	c7 40 04 03 00 00 00 	movl   $0x3,0x4(%eax)
  schedule ();
c0020fa6:	e8 34 fe ff ff       	call   c0020ddf <schedule>
  NOT_REACHED ();
c0020fab:	68 4c d2 02 c0       	push   $0xc002d24c
c0020fb0:	68 f4 b6 02 c0       	push   $0xc002b6f4
c0020fb5:	68 2e 01 00 00       	push   $0x12e
c0020fba:	68 ee d0 02 c0       	push   $0xc002d0ee
c0020fbf:	e8 4b 68 00 00       	call   c002780f <debug_panic>

c0020fc4 <kernel_thread>:
{
c0020fc4:	53                   	push   %ebx
c0020fc5:	83 ec 08             	sub    $0x8,%esp
c0020fc8:	8b 5c 24 10          	mov    0x10(%esp),%ebx
  ASSERT (function != NULL);
c0020fcc:	85 db                	test   %ebx,%ebx
c0020fce:	74 13                	je     c0020fe3 <kernel_thread+0x1f>
  intr_enable ();       /* The scheduler runs with interrupts off. */
c0020fd0:	e8 4b 02 00 00       	call   c0021220 <intr_enable>
  function (aux);       /* Execute the thread function. */
c0020fd5:	83 ec 0c             	sub    $0xc,%esp
c0020fd8:	ff 74 24 20          	pushl  0x20(%esp)
c0020fdc:	ff d3                	call   *%ebx
  thread_exit ();       /* If function() returns, kill the thread. */
c0020fde:	e8 74 ff ff ff       	call   c0020f57 <thread_exit>
  ASSERT (function != NULL);
c0020fe3:	83 ec 0c             	sub    $0xc,%esp
c0020fe6:	68 5f d1 02 c0       	push   $0xc002d15f
c0020feb:	68 9f cd 02 c0       	push   $0xc002cd9f
c0020ff0:	68 48 b7 02 c0       	push   $0xc002b748
c0020ff5:	68 da 01 00 00       	push   $0x1da
c0020ffa:	68 ee d0 02 c0       	push   $0xc002d0ee
c0020fff:	e8 0b 68 00 00       	call   c002780f <debug_panic>

c0021004 <thread_yield>:
{
c0021004:	56                   	push   %esi
c0021005:	53                   	push   %ebx
c0021006:	83 ec 04             	sub    $0x4,%esp
  struct thread *cur = thread_current ();
c0021009:	e8 41 fb ff ff       	call   c0020b4f <thread_current>
c002100e:	89 c3                	mov    %eax,%ebx
  ASSERT (!intr_context ());
c0021010:	e8 60 04 00 00       	call   c0021475 <intr_context>
c0021015:	84 c0                	test   %al,%al
c0021017:	75 3e                	jne    c0021057 <thread_yield+0x53>
  old_level = intr_disable ();
c0021019:	e8 36 02 00 00       	call   c0021254 <intr_disable>
c002101e:	89 c6                	mov    %eax,%esi
  if (cur != idle_thread) 
c0021020:	3b 1d 5c 6a 03 c0    	cmp    0xc0036a5c,%ebx
c0021026:	74 14                	je     c002103c <thread_yield+0x38>
    list_push_back (&ready_list, &cur->elem);
c0021028:	83 ec 08             	sub    $0x8,%esp
c002102b:	8d 43 38             	lea    0x38(%ebx),%eax
c002102e:	50                   	push   %eax
c002102f:	68 80 6a 03 c0       	push   $0xc0036a80
c0021034:	e8 1a 6d 00 00       	call   c0027d53 <list_push_back>
c0021039:	83 c4 10             	add    $0x10,%esp
  cur->status = THREAD_READY;
c002103c:	c7 43 04 01 00 00 00 	movl   $0x1,0x4(%ebx)
  schedule ();
c0021043:	e8 97 fd ff ff       	call   c0020ddf <schedule>
  intr_set_level (old_level);
c0021048:	83 ec 0c             	sub    $0xc,%esp
c002104b:	56                   	push   %esi
c002104c:	e8 0a 02 00 00       	call   c002125b <intr_set_level>
}
c0021051:	83 c4 14             	add    $0x14,%esp
c0021054:	5b                   	pop    %ebx
c0021055:	5e                   	pop    %esi
c0021056:	c3                   	ret    
  ASSERT (!intr_context ());
c0021057:	83 ec 0c             	sub    $0xc,%esp
c002105a:	68 cc d1 02 c0       	push   $0xc002d1cc
c002105f:	68 9f cd 02 c0       	push   $0xc002cd9f
c0021064:	68 e4 b6 02 c0       	push   $0xc002b6e4
c0021069:	68 39 01 00 00       	push   $0x139
c002106e:	68 ee d0 02 c0       	push   $0xc002d0ee
c0021073:	e8 97 67 00 00       	call   c002780f <debug_panic>

c0021078 <thread_sleep>:

  return tid;
}

void thread_sleep (int64_t ticks){
c0021078:	57                   	push   %edi
c0021079:	56                   	push   %esi
c002107a:	53                   	push   %ebx
c002107b:	8b 74 24 10          	mov    0x10(%esp),%esi
c002107f:	8b 7c 24 14          	mov    0x14(%esp),%edi
  enum intr_level old_level;
  
  // ASSERT (!intr_context ());
  old_level = intr_disable ();
c0021083:	e8 cc 01 00 00       	call   c0021254 <intr_disable>
c0021088:	89 c3                	mov    %eax,%ebx

  struct thread *t = thread_current ();
c002108a:	e8 c0 fa ff ff       	call   c0020b4f <thread_current>
  if (t != idle_thread) {
c002108f:	3b 05 5c 6a 03 c0    	cmp    0xc0036a5c,%eax
c0021095:	74 1f                	je     c00210b6 <thread_sleep+0x3e>
    t->wakeup_tick = ticks;
c0021097:	89 70 28             	mov    %esi,0x28(%eax)
c002109a:	89 78 2c             	mov    %edi,0x2c(%eax)
    list_push_back (&sleep_list, &t->sleepelem);
c002109d:	83 ec 08             	sub    $0x8,%esp
c00210a0:	83 c0 30             	add    $0x30,%eax
c00210a3:	50                   	push   %eax
c00210a4:	68 70 6a 03 c0       	push   $0xc0036a70
c00210a9:	e8 a5 6c 00 00       	call   c0027d53 <list_push_back>
    // printf("thread %d in sleep list, sleeps for %lld ticks\n", t->tid, ticks);
    // printf("before block: thread %d status: %d\n", t->tid, t->status);
    thread_block();
c00210ae:	e8 0e fe ff ff       	call   c0020ec1 <thread_block>
c00210b3:	83 c4 10             	add    $0x10,%esp

  }


  intr_set_level (old_level);
c00210b6:	83 ec 0c             	sub    $0xc,%esp
c00210b9:	53                   	push   %ebx
c00210ba:	e8 9c 01 00 00       	call   c002125b <intr_set_level>
}
c00210bf:	83 c4 10             	add    $0x10,%esp
c00210c2:	5b                   	pop    %ebx
c00210c3:	5e                   	pop    %esi
c00210c4:	5f                   	pop    %edi
c00210c5:	c3                   	ret    

c00210c6 <switch_threads>:
	# but requires us to preserve %ebx, %ebp, %esi, %edi.  See
	# [SysV-ABI-386] pages 3-11 and 3-12 for details.
	#
	# This stack frame must match the one set up by thread_create()
	# in size.
	pushl %ebx
c00210c6:	53                   	push   %ebx
	pushl %ebp
c00210c7:	55                   	push   %ebp
	pushl %esi
c00210c8:	56                   	push   %esi
	pushl %edi
c00210c9:	57                   	push   %edi

	# Get offsetof (struct thread, stack).
.globl thread_stack_ofs
	mov thread_stack_ofs, %edx
c00210ca:	8b 15 c8 64 03 c0    	mov    0xc00364c8,%edx

	# Save current stack pointer to old thread's stack, if any.
	movl SWITCH_CUR(%esp), %eax
c00210d0:	8b 44 24 14          	mov    0x14(%esp),%eax
	movl %esp, (%eax,%edx,1)
c00210d4:	89 24 10             	mov    %esp,(%eax,%edx,1)

	# Restore stack pointer from new thread's stack.
	movl SWITCH_NEXT(%esp), %ecx
c00210d7:	8b 4c 24 18          	mov    0x18(%esp),%ecx
	movl (%ecx,%edx,1), %esp
c00210db:	8b 24 11             	mov    (%ecx,%edx,1),%esp

	# Restore caller's register state.
	popl %edi
c00210de:	5f                   	pop    %edi
	popl %esi
c00210df:	5e                   	pop    %esi
	popl %ebp
c00210e0:	5d                   	pop    %ebp
	popl %ebx
c00210e1:	5b                   	pop    %ebx
        ret
c00210e2:	c3                   	ret    

c00210e3 <switch_entry>:

.globl switch_entry
.func switch_entry
switch_entry:
	# Discard switch_threads() arguments.
	addl $8, %esp
c00210e3:	83 c4 08             	add    $0x8,%esp

	# Call thread_schedule_tail(prev).
	pushl %eax
c00210e6:	50                   	push   %eax
.globl thread_schedule_tail
	call thread_schedule_tail
c00210e7:	e8 5c fc ff ff       	call   c0020d48 <thread_schedule_tail>
	addl $4, %esp
c00210ec:	83 c4 04             	add    $0x4,%esp

	# Start thread proper.
	ret
c00210ef:	c3                   	ret    

c00210f0 <make_gate>:
   disables interrupts, but entering a trap gate does not.  See
   [IA32-v3a] section 5.12.1.2 "Flag Usage By Exception- or
   Interrupt-Handler Procedure" for discussion. */
static uint64_t
make_gate (void (*function) (void), int dpl, int type)
{
c00210f0:	83 ec 0c             	sub    $0xc,%esp
  uint32_t e0, e1;

  ASSERT (function != NULL);
c00210f3:	85 c0                	test   %eax,%eax
c00210f5:	74 2b                	je     c0021122 <make_gate+0x32>
  ASSERT (dpl >= 0 && dpl <= 3);
c00210f7:	83 fa 03             	cmp    $0x3,%edx
c00210fa:	77 47                	ja     c0021143 <make_gate+0x53>
  ASSERT (type >= 0 && type <= 15);
c00210fc:	83 f9 0f             	cmp    $0xf,%ecx
c00210ff:	77 63                	ja     c0021164 <make_gate+0x74>

  e1 = (((uint32_t) function & 0xffff0000) /* Offset 31:16. */
        | (1 << 15)                        /* Present. */
        | ((uint32_t) dpl << 13)           /* Descriptor privilege level. */
        | (0 << 12)                        /* System. */
        | ((uint32_t) type << 8));         /* Gate type. */
c0021101:	c1 e1 08             	shl    $0x8,%ecx
  e1 = (((uint32_t) function & 0xffff0000) /* Offset 31:16. */
c0021104:	80 cd 80             	or     $0x80,%ch
        | ((uint32_t) dpl << 13)           /* Descriptor privilege level. */
c0021107:	c1 e2 0d             	shl    $0xd,%edx
  e1 = (((uint32_t) function & 0xffff0000) /* Offset 31:16. */
c002110a:	09 ca                	or     %ecx,%edx
c002110c:	89 c1                	mov    %eax,%ecx
c002110e:	81 e1 00 00 ff ff    	and    $0xffff0000,%ecx
c0021114:	09 ca                	or     %ecx,%edx
  e0 = (((uint32_t) function & 0xffff)     /* Offset 15:0. */
c0021116:	0f b7 c0             	movzwl %ax,%eax
c0021119:	0d 00 00 08 00       	or     $0x80000,%eax

  return e0 | ((uint64_t) e1 << 32);
}
c002111e:	83 c4 0c             	add    $0xc,%esp
c0021121:	c3                   	ret    
  ASSERT (function != NULL);
c0021122:	83 ec 0c             	sub    $0xc,%esp
c0021125:	68 5f d1 02 c0       	push   $0xc002d15f
c002112a:	68 9f cd 02 c0       	push   $0xc002cd9f
c002112f:	68 fc b7 02 c0       	push   $0xc002b7fc
c0021134:	68 2a 01 00 00       	push   $0x12a
c0021139:	68 6e d2 02 c0       	push   $0xc002d26e
c002113e:	e8 cc 66 00 00       	call   c002780f <debug_panic>
  ASSERT (dpl >= 0 && dpl <= 3);
c0021143:	83 ec 0c             	sub    $0xc,%esp
c0021146:	68 88 d2 02 c0       	push   $0xc002d288
c002114b:	68 9f cd 02 c0       	push   $0xc002cd9f
c0021150:	68 fc b7 02 c0       	push   $0xc002b7fc
c0021155:	68 2b 01 00 00       	push   $0x12b
c002115a:	68 6e d2 02 c0       	push   $0xc002d26e
c002115f:	e8 ab 66 00 00       	call   c002780f <debug_panic>
  ASSERT (type >= 0 && type <= 15);
c0021164:	83 ec 0c             	sub    $0xc,%esp
c0021167:	68 9d d2 02 c0       	push   $0xc002d29d
c002116c:	68 9f cd 02 c0       	push   $0xc002cd9f
c0021171:	68 fc b7 02 c0       	push   $0xc002b7fc
c0021176:	68 2c 01 00 00       	push   $0x12c
c002117b:	68 6e d2 02 c0       	push   $0xc002d26e
c0021180:	e8 8a 66 00 00       	call   c002780f <debug_panic>

c0021185 <register_handler>:
{
c0021185:	53                   	push   %ebx
c0021186:	83 ec 08             	sub    $0x8,%esp
  ASSERT (intr_handlers[vec_no] == NULL);
c0021189:	0f b6 d8             	movzbl %al,%ebx
c002118c:	83 3c 9d c0 72 03 c0 	cmpl   $0x0,-0x3ffc8d40(,%ebx,4)
c0021193:	00 
c0021194:	75 3f                	jne    c00211d5 <register_handler+0x50>
  if (level == INTR_ON)
c0021196:	83 f9 01             	cmp    $0x1,%ecx
c0021199:	74 5b                	je     c00211f6 <register_handler+0x71>
/* Creates an interrupt gate that invokes FUNCTION with the given
   DPL. */
static uint64_t
make_intr_gate (void (*function) (void), int dpl)
{
  return make_gate (function, dpl, 14);
c002119b:	8b 04 9d cc 64 03 c0 	mov    -0x3ffc9b34(,%ebx,4),%eax
c00211a2:	b9 0e 00 00 00       	mov    $0xe,%ecx
c00211a7:	e8 44 ff ff ff       	call   c00210f0 <make_gate>
    idt[vec_no] = make_intr_gate (intr_stubs[vec_no], dpl);
c00211ac:	89 04 dd c0 76 03 c0 	mov    %eax,-0x3ffc8940(,%ebx,8)
c00211b3:	89 14 dd c4 76 03 c0 	mov    %edx,-0x3ffc893c(,%ebx,8)
  intr_handlers[vec_no] = handler;
c00211ba:	8b 44 24 10          	mov    0x10(%esp),%eax
c00211be:	89 04 9d c0 72 03 c0 	mov    %eax,-0x3ffc8d40(,%ebx,4)
  intr_names[vec_no] = name;
c00211c5:	8b 44 24 14          	mov    0x14(%esp),%eax
c00211c9:	89 04 9d c0 6e 03 c0 	mov    %eax,-0x3ffc9140(,%ebx,4)
}
c00211d0:	83 c4 08             	add    $0x8,%esp
c00211d3:	5b                   	pop    %ebx
c00211d4:	c3                   	ret    
  ASSERT (intr_handlers[vec_no] == NULL);
c00211d5:	83 ec 0c             	sub    $0xc,%esp
c00211d8:	68 b5 d2 02 c0       	push   $0xc002d2b5
c00211dd:	68 9f cd 02 c0       	push   $0xc002cd9f
c00211e2:	68 d4 b7 02 c0       	push   $0xc002b7d4
c00211e7:	68 a8 00 00 00       	push   $0xa8
c00211ec:	68 6e d2 02 c0       	push   $0xc002d26e
c00211f1:	e8 19 66 00 00       	call   c002780f <debug_panic>
/* Creates a trap gate that invokes FUNCTION with the given
   DPL. */
static uint64_t
make_trap_gate (void (*function) (void), int dpl)
{
  return make_gate (function, dpl, 15);
c00211f6:	8b 04 9d cc 64 03 c0 	mov    -0x3ffc9b34(,%ebx,4),%eax
c00211fd:	b9 0f 00 00 00       	mov    $0xf,%ecx
c0021202:	e8 e9 fe ff ff       	call   c00210f0 <make_gate>
    idt[vec_no] = make_trap_gate (intr_stubs[vec_no], dpl);
c0021207:	89 04 dd c0 76 03 c0 	mov    %eax,-0x3ffc8940(,%ebx,8)
c002120e:	89 14 dd c4 76 03 c0 	mov    %edx,-0x3ffc893c(,%ebx,8)
c0021215:	eb a3                	jmp    c00211ba <register_handler+0x35>

c0021217 <intr_get_level>:
  asm volatile ("pushfl; popl %0" : "=g" (flags));
c0021217:	9c                   	pushf  
c0021218:	58                   	pop    %eax
  return flags & FLAG_IF ? INTR_ON : INTR_OFF;
c0021219:	c1 e8 09             	shr    $0x9,%eax
c002121c:	83 e0 01             	and    $0x1,%eax
}
c002121f:	c3                   	ret    

c0021220 <intr_enable>:
{
c0021220:	83 ec 0c             	sub    $0xc,%esp
  enum intr_level old_level = intr_get_level ();
c0021223:	e8 ef ff ff ff       	call   c0021217 <intr_get_level>
  ASSERT (!intr_context ());
c0021228:	80 3d a1 6a 03 c0 00 	cmpb   $0x0,0xc0036aa1
c002122f:	75 05                	jne    c0021236 <intr_enable+0x16>
  asm volatile ("sti");
c0021231:	fb                   	sti    
}
c0021232:	83 c4 0c             	add    $0xc,%esp
c0021235:	c3                   	ret    
  ASSERT (!intr_context ());
c0021236:	83 ec 0c             	sub    $0xc,%esp
c0021239:	68 cc d1 02 c0       	push   $0xc002d1cc
c002123e:	68 9f cd 02 c0       	push   $0xc002cd9f
c0021243:	68 08 b8 02 c0       	push   $0xc002b808
c0021248:	6a 5b                	push   $0x5b
c002124a:	68 6e d2 02 c0       	push   $0xc002d26e
c002124f:	e8 bb 65 00 00       	call   c002780f <debug_panic>

c0021254 <intr_disable>:
  enum intr_level old_level = intr_get_level ();
c0021254:	e8 be ff ff ff       	call   c0021217 <intr_get_level>
  asm volatile ("cli" : : : "memory");
c0021259:	fa                   	cli    
}
c002125a:	c3                   	ret    

c002125b <intr_set_level>:
{
c002125b:	83 ec 0c             	sub    $0xc,%esp
  return level == INTR_ON ? intr_enable () : intr_disable ();
c002125e:	83 7c 24 10 01       	cmpl   $0x1,0x10(%esp)
c0021263:	74 09                	je     c002126e <intr_set_level+0x13>
c0021265:	e8 ea ff ff ff       	call   c0021254 <intr_disable>
}
c002126a:	83 c4 0c             	add    $0xc,%esp
c002126d:	c3                   	ret    
  return level == INTR_ON ? intr_enable () : intr_disable ();
c002126e:	e8 ad ff ff ff       	call   c0021220 <intr_enable>
c0021273:	eb f5                	jmp    c002126a <intr_set_level+0xf>

c0021275 <intr_init>:
{
c0021275:	53                   	push   %ebx
c0021276:	83 ec 18             	sub    $0x18,%esp
/* Writes byte DATA to PORT. */
static inline void
outb (uint16_t port, uint8_t data)
{
  /* See [IA32-v2b] "OUT". */
  asm volatile ("outb %b0, %w1" : : "a" (data), "Nd" (port));
c0021279:	b0 ff                	mov    $0xff,%al
c002127b:	e6 21                	out    %al,$0x21
c002127d:	e6 a1                	out    %al,$0xa1
c002127f:	b0 11                	mov    $0x11,%al
c0021281:	e6 20                	out    %al,$0x20
c0021283:	b0 20                	mov    $0x20,%al
c0021285:	e6 21                	out    %al,$0x21
c0021287:	b0 04                	mov    $0x4,%al
c0021289:	e6 21                	out    %al,$0x21
c002128b:	b0 01                	mov    $0x1,%al
c002128d:	e6 21                	out    %al,$0x21
c002128f:	b0 11                	mov    $0x11,%al
c0021291:	e6 a0                	out    %al,$0xa0
c0021293:	b0 28                	mov    $0x28,%al
c0021295:	e6 a1                	out    %al,$0xa1
c0021297:	b0 02                	mov    $0x2,%al
c0021299:	e6 a1                	out    %al,$0xa1
c002129b:	b0 01                	mov    $0x1,%al
c002129d:	e6 a1                	out    %al,$0xa1
c002129f:	b0 00                	mov    $0x0,%al
c00212a1:	e6 21                	out    %al,$0x21
c00212a3:	e6 a1                	out    %al,$0xa1
c00212a5:	bb 00 00 00 00       	mov    $0x0,%ebx
  return make_gate (function, dpl, 14);
c00212aa:	8b 83 cc 64 03 c0    	mov    -0x3ffc9b34(%ebx),%eax
c00212b0:	b9 0e 00 00 00       	mov    $0xe,%ecx
c00212b5:	ba 00 00 00 00       	mov    $0x0,%edx
c00212ba:	e8 31 fe ff ff       	call   c00210f0 <make_gate>
    idt[i] = make_intr_gate (intr_stubs[i], 0);
c00212bf:	89 84 1b c0 76 03 c0 	mov    %eax,-0x3ffc8940(%ebx,%ebx,1)
c00212c6:	89 94 1b c4 76 03 c0 	mov    %edx,-0x3ffc893c(%ebx,%ebx,1)
c00212cd:	83 c3 04             	add    $0x4,%ebx
  for (i = 0; i < INTR_CNT; i++)
c00212d0:	81 fb 00 04 00 00    	cmp    $0x400,%ebx
c00212d6:	75 d2                	jne    c00212aa <intr_init+0x35>
/* Returns a descriptor that yields the given LIMIT and BASE when
   used as an operand for the LIDT instruction. */
static inline uint64_t
make_idtr_operand (uint16_t limit, void *base)
{
  return limit | ((uint64_t) (uint32_t) base << 16);
c00212d8:	b8 c0 76 03 c0       	mov    $0xc00376c0,%eax
c00212dd:	ba 00 00 00 00       	mov    $0x0,%edx
c00212e2:	0f a4 c2 10          	shld   $0x10,%eax,%edx
c00212e6:	c1 e0 10             	shl    $0x10,%eax
c00212e9:	0d ff 07 00 00       	or     $0x7ff,%eax
c00212ee:	89 44 24 08          	mov    %eax,0x8(%esp)
c00212f2:	89 54 24 0c          	mov    %edx,0xc(%esp)
  asm volatile ("lidt %0" : : "m" (idtr_operand));
c00212f6:	0f 01 5c 24 08       	lidtl  0x8(%esp)
c00212fb:	b8 c0 6e 03 c0       	mov    $0xc0036ec0,%eax
c0021300:	ba c0 72 03 c0       	mov    $0xc00372c0,%edx
    intr_names[i] = "unknown";
c0021305:	c7 00 d3 d2 02 c0    	movl   $0xc002d2d3,(%eax)
c002130b:	83 c0 04             	add    $0x4,%eax
  for (i = 0; i < INTR_CNT; i++)
c002130e:	39 c2                	cmp    %eax,%edx
c0021310:	75 f3                	jne    c0021305 <intr_init+0x90>
  intr_names[0] = "#DE Divide Error";
c0021312:	c7 05 c0 6e 03 c0 db 	movl   $0xc002d2db,0xc0036ec0
c0021319:	d2 02 c0 
  intr_names[1] = "#DB Debug Exception";
c002131c:	c7 05 c4 6e 03 c0 ec 	movl   $0xc002d2ec,0xc0036ec4
c0021323:	d2 02 c0 
  intr_names[2] = "NMI Interrupt";
c0021326:	c7 05 c8 6e 03 c0 00 	movl   $0xc002d300,0xc0036ec8
c002132d:	d3 02 c0 
  intr_names[3] = "#BP Breakpoint Exception";
c0021330:	c7 05 cc 6e 03 c0 0e 	movl   $0xc002d30e,0xc0036ecc
c0021337:	d3 02 c0 
  intr_names[4] = "#OF Overflow Exception";
c002133a:	c7 05 d0 6e 03 c0 27 	movl   $0xc002d327,0xc0036ed0
c0021341:	d3 02 c0 
  intr_names[5] = "#BR BOUND Range Exceeded Exception";
c0021344:	c7 05 d4 6e 03 c0 64 	movl   $0xc002d464,0xc0036ed4
c002134b:	d4 02 c0 
  intr_names[6] = "#UD Invalid Opcode Exception";
c002134e:	c7 05 d8 6e 03 c0 3e 	movl   $0xc002d33e,0xc0036ed8
c0021355:	d3 02 c0 
  intr_names[7] = "#NM Device Not Available Exception";
c0021358:	c7 05 dc 6e 03 c0 88 	movl   $0xc002d488,0xc0036edc
c002135f:	d4 02 c0 
  intr_names[8] = "#DF Double Fault Exception";
c0021362:	c7 05 e0 6e 03 c0 5b 	movl   $0xc002d35b,0xc0036ee0
c0021369:	d3 02 c0 
  intr_names[9] = "Coprocessor Segment Overrun";
c002136c:	c7 05 e4 6e 03 c0 76 	movl   $0xc002d376,0xc0036ee4
c0021373:	d3 02 c0 
  intr_names[10] = "#TS Invalid TSS Exception";
c0021376:	c7 05 e8 6e 03 c0 92 	movl   $0xc002d392,0xc0036ee8
c002137d:	d3 02 c0 
  intr_names[11] = "#NP Segment Not Present";
c0021380:	c7 05 ec 6e 03 c0 ac 	movl   $0xc002d3ac,0xc0036eec
c0021387:	d3 02 c0 
  intr_names[12] = "#SS Stack Fault Exception";
c002138a:	c7 05 f0 6e 03 c0 c4 	movl   $0xc002d3c4,0xc0036ef0
c0021391:	d3 02 c0 
  intr_names[13] = "#GP General Protection Exception";
c0021394:	c7 05 f4 6e 03 c0 ac 	movl   $0xc002d4ac,0xc0036ef4
c002139b:	d4 02 c0 
  intr_names[14] = "#PF Page-Fault Exception";
c002139e:	c7 05 f8 6e 03 c0 de 	movl   $0xc002d3de,0xc0036ef8
c00213a5:	d3 02 c0 
  intr_names[16] = "#MF x87 FPU Floating-Point Error";
c00213a8:	c7 05 00 6f 03 c0 d0 	movl   $0xc002d4d0,0xc0036f00
c00213af:	d4 02 c0 
  intr_names[17] = "#AC Alignment Check Exception";
c00213b2:	c7 05 04 6f 03 c0 f7 	movl   $0xc002d3f7,0xc0036f04
c00213b9:	d3 02 c0 
  intr_names[18] = "#MC Machine-Check Exception";
c00213bc:	c7 05 08 6f 03 c0 15 	movl   $0xc002d415,0xc0036f08
c00213c3:	d4 02 c0 
  intr_names[19] = "#XF SIMD Floating-Point Exception";
c00213c6:	c7 05 0c 6f 03 c0 f4 	movl   $0xc002d4f4,0xc0036f0c
c00213cd:	d4 02 c0 
}
c00213d0:	83 c4 18             	add    $0x18,%esp
c00213d3:	5b                   	pop    %ebx
c00213d4:	c3                   	ret    

c00213d5 <intr_register_ext>:
{
c00213d5:	83 ec 0c             	sub    $0xc,%esp
c00213d8:	8b 44 24 10          	mov    0x10(%esp),%eax
  ASSERT (vec_no >= 0x20 && vec_no <= 0x2f);
c00213dc:	8d 50 e0             	lea    -0x20(%eax),%edx
c00213df:	80 fa 0f             	cmp    $0xf,%dl
c00213e2:	77 21                	ja     c0021405 <intr_register_ext+0x30>
  register_handler (vec_no, 0, INTR_OFF, handler, name);
c00213e4:	0f b6 c0             	movzbl %al,%eax
c00213e7:	83 ec 08             	sub    $0x8,%esp
c00213ea:	ff 74 24 20          	pushl  0x20(%esp)
c00213ee:	ff 74 24 20          	pushl  0x20(%esp)
c00213f2:	b9 00 00 00 00       	mov    $0x0,%ecx
c00213f7:	ba 00 00 00 00       	mov    $0x0,%edx
c00213fc:	e8 84 fd ff ff       	call   c0021185 <register_handler>
}
c0021401:	83 c4 1c             	add    $0x1c,%esp
c0021404:	c3                   	ret    
  ASSERT (vec_no >= 0x20 && vec_no <= 0x2f);
c0021405:	83 ec 0c             	sub    $0xc,%esp
c0021408:	68 18 d5 02 c0       	push   $0xc002d518
c002140d:	68 9f cd 02 c0       	push   $0xc002cd9f
c0021412:	68 e8 b7 02 c0       	push   $0xc002b7e8
c0021417:	68 b8 00 00 00       	push   $0xb8
c002141c:	68 6e d2 02 c0       	push   $0xc002d26e
c0021421:	e8 e9 63 00 00       	call   c002780f <debug_panic>

c0021426 <intr_register_int>:
{
c0021426:	83 ec 0c             	sub    $0xc,%esp
c0021429:	8b 44 24 10          	mov    0x10(%esp),%eax
  ASSERT (vec_no < 0x20 || vec_no > 0x2f);
c002142d:	8d 50 e0             	lea    -0x20(%eax),%edx
c0021430:	80 fa 0f             	cmp    $0xf,%dl
c0021433:	76 1f                	jbe    c0021454 <intr_register_int+0x2e>
  register_handler (vec_no, dpl, level, handler, name);
c0021435:	0f b6 c0             	movzbl %al,%eax
c0021438:	83 ec 08             	sub    $0x8,%esp
c002143b:	ff 74 24 28          	pushl  0x28(%esp)
c002143f:	ff 74 24 28          	pushl  0x28(%esp)
c0021443:	8b 4c 24 28          	mov    0x28(%esp),%ecx
c0021447:	8b 54 24 24          	mov    0x24(%esp),%edx
c002144b:	e8 35 fd ff ff       	call   c0021185 <register_handler>
}
c0021450:	83 c4 1c             	add    $0x1c,%esp
c0021453:	c3                   	ret    
  ASSERT (vec_no < 0x20 || vec_no > 0x2f);
c0021454:	83 ec 0c             	sub    $0xc,%esp
c0021457:	68 3c d5 02 c0       	push   $0xc002d53c
c002145c:	68 9f cd 02 c0       	push   $0xc002cd9f
c0021461:	68 c0 b7 02 c0       	push   $0xc002b7c0
c0021466:	68 cd 00 00 00       	push   $0xcd
c002146b:	68 6e d2 02 c0       	push   $0xc002d26e
c0021470:	e8 9a 63 00 00       	call   c002780f <debug_panic>

c0021475 <intr_context>:
}
c0021475:	a0 a1 6a 03 c0       	mov    0xc0036aa1,%al
c002147a:	c3                   	ret    

c002147b <intr_yield_on_return>:
  ASSERT (intr_context ());
c002147b:	80 3d a1 6a 03 c0 00 	cmpb   $0x0,0xc0036aa1
c0021482:	74 08                	je     c002148c <intr_yield_on_return+0x11>
  yield_on_return = true;
c0021484:	c6 05 a0 6a 03 c0 01 	movb   $0x1,0xc0036aa0
c002148b:	c3                   	ret    
{
c002148c:	83 ec 18             	sub    $0x18,%esp
  ASSERT (intr_context ());
c002148f:	68 cd d1 02 c0       	push   $0xc002d1cd
c0021494:	68 9f cd 02 c0       	push   $0xc002cd9f
c0021499:	68 a8 b7 02 c0       	push   $0xc002b7a8
c002149e:	68 e0 00 00 00       	push   $0xe0
c00214a3:	68 6e d2 02 c0       	push   $0xc002d26e
c00214a8:	e8 62 63 00 00       	call   c002780f <debug_panic>

c00214ad <intr_handler>:
   function is called by the assembly language interrupt stubs in
   intr-stubs.S.  FRAME describes the interrupt and the
   interrupted thread's registers. */
void
intr_handler (struct intr_frame *frame) 
{
c00214ad:	56                   	push   %esi
c00214ae:	53                   	push   %ebx
c00214af:	83 ec 04             	sub    $0x4,%esp
c00214b2:	8b 74 24 10          	mov    0x10(%esp),%esi

  /* External interrupts are special.
     We only handle one at a time (so interrupts must be off)
     and they need to be acknowledged on the PIC (see below).
     An external interrupt handler cannot sleep. */
  external = frame->vec_no >= 0x20 && frame->vec_no < 0x30;
c00214b6:	8b 46 30             	mov    0x30(%esi),%eax
c00214b9:	8d 58 e0             	lea    -0x20(%eax),%ebx
  if (external) 
c00214bc:	83 fb 0f             	cmp    $0xf,%ebx
c00214bf:	76 26                	jbe    c00214e7 <intr_handler+0x3a>
      in_external_intr = true;
      yield_on_return = false;
    }

  /* Invoke the interrupt's handler. */
  handler = intr_handlers[frame->vec_no];
c00214c1:	8b 56 30             	mov    0x30(%esi),%edx
c00214c4:	8b 04 95 c0 72 03 c0 	mov    -0x3ffc8d40(,%edx,4),%eax
  if (handler != NULL)
c00214cb:	85 c0                	test   %eax,%eax
c00214cd:	74 7c                	je     c002154b <intr_handler+0x9e>
    handler (frame);
c00214cf:	83 ec 0c             	sub    $0xc,%esp
c00214d2:	56                   	push   %esi
c00214d3:	ff d0                	call   *%eax
c00214d5:	83 c4 10             	add    $0x10,%esp
    }
  else
    unexpected_interrupt (frame);

  /* Complete the processing of an external interrupt. */
  if (external) 
c00214d8:	83 fb 0f             	cmp    $0xf,%ebx
c00214db:	0f 86 aa 00 00 00    	jbe    c002158b <intr_handler+0xde>
      pic_end_of_interrupt (frame->vec_no); 

      if (yield_on_return) 
        thread_yield (); 
    }
}
c00214e1:	83 c4 04             	add    $0x4,%esp
c00214e4:	5b                   	pop    %ebx
c00214e5:	5e                   	pop    %esi
c00214e6:	c3                   	ret    
      ASSERT (intr_get_level () == INTR_OFF);
c00214e7:	e8 2b fd ff ff       	call   c0021217 <intr_get_level>
c00214ec:	85 c0                	test   %eax,%eax
c00214ee:	75 19                	jne    c0021509 <intr_handler+0x5c>
      ASSERT (!intr_context ());
c00214f0:	80 3d a1 6a 03 c0 00 	cmpb   $0x0,0xc0036aa1
c00214f7:	75 31                	jne    c002152a <intr_handler+0x7d>
      in_external_intr = true;
c00214f9:	c6 05 a1 6a 03 c0 01 	movb   $0x1,0xc0036aa1
      yield_on_return = false;
c0021500:	c6 05 a0 6a 03 c0 00 	movb   $0x0,0xc0036aa0
c0021507:	eb b8                	jmp    c00214c1 <intr_handler+0x14>
      ASSERT (intr_get_level () == INTR_OFF);
c0021509:	83 ec 0c             	sub    $0xc,%esp
c002150c:	68 20 d1 02 c0       	push   $0xc002d120
c0021511:	68 9f cd 02 c0       	push   $0xc002cd9f
c0021516:	68 98 b7 02 c0       	push   $0xc002b798
c002151b:	68 65 01 00 00       	push   $0x165
c0021520:	68 6e d2 02 c0       	push   $0xc002d26e
c0021525:	e8 e5 62 00 00       	call   c002780f <debug_panic>
      ASSERT (!intr_context ());
c002152a:	83 ec 0c             	sub    $0xc,%esp
c002152d:	68 cc d1 02 c0       	push   $0xc002d1cc
c0021532:	68 9f cd 02 c0       	push   $0xc002cd9f
c0021537:	68 98 b7 02 c0       	push   $0xc002b798
c002153c:	68 66 01 00 00       	push   $0x166
c0021541:	68 6e d2 02 c0       	push   $0xc002d26e
c0021546:	e8 c4 62 00 00       	call   c002780f <debug_panic>
  else if (frame->vec_no == 0x27 || frame->vec_no == 0x2f)
c002154b:	89 d0                	mov    %edx,%eax
c002154d:	83 e0 f7             	and    $0xfffffff7,%eax
c0021550:	83 f8 27             	cmp    $0x27,%eax
c0021553:	74 83                	je     c00214d8 <intr_handler+0x2b>
   unexpected interrupt is one that has no registered handler. */
static void
unexpected_interrupt (const struct intr_frame *f)
{
  /* Count the number so far. */
  unsigned int n = ++unexpected_cnt[f->vec_no];
c0021555:	8b 0c 95 c0 6a 03 c0 	mov    -0x3ffc9540(,%edx,4),%ecx
c002155c:	8d 41 01             	lea    0x1(%ecx),%eax
c002155f:	89 04 95 c0 6a 03 c0 	mov    %eax,-0x3ffc9540(,%edx,4)
  /* If the number is a power of 2, print a message.  This rate
     limiting means that we get information about an uncommon
     unexpected interrupt the first time and fairly often after
     that, but one that occurs many times will not overwhelm the
     console. */
  if ((n & (n - 1)) == 0)
c0021566:	85 c1                	test   %eax,%ecx
c0021568:	0f 85 6a ff ff ff    	jne    c00214d8 <intr_handler+0x2b>
    printf ("Unexpected interrupt %#04x (%s)\n",
c002156e:	83 ec 04             	sub    $0x4,%esp
c0021571:	ff 34 95 c0 6e 03 c0 	pushl  -0x3ffc9140(,%edx,4)
c0021578:	52                   	push   %edx
c0021579:	68 5c d5 02 c0       	push   $0xc002d55c
c002157e:	e8 de 47 00 00       	call   c0025d61 <printf>
c0021583:	83 c4 10             	add    $0x10,%esp
c0021586:	e9 4d ff ff ff       	jmp    c00214d8 <intr_handler+0x2b>
      ASSERT (intr_get_level () == INTR_OFF);
c002158b:	e8 87 fc ff ff       	call   c0021217 <intr_get_level>
c0021590:	85 c0                	test   %eax,%eax
c0021592:	75 3d                	jne    c00215d1 <intr_handler+0x124>
      ASSERT (intr_context ());
c0021594:	80 3d a1 6a 03 c0 00 	cmpb   $0x0,0xc0036aa1
c002159b:	74 55                	je     c00215f2 <intr_handler+0x145>
      in_external_intr = false;
c002159d:	c6 05 a1 6a 03 c0 00 	movb   $0x0,0xc0036aa1
      pic_end_of_interrupt (frame->vec_no); 
c00215a4:	8b 56 30             	mov    0x30(%esi),%edx
  ASSERT (irq >= 0x20 && irq < 0x30);
c00215a7:	8d 42 e0             	lea    -0x20(%edx),%eax
c00215aa:	83 f8 0f             	cmp    $0xf,%eax
c00215ad:	77 64                	ja     c0021613 <intr_handler+0x166>
c00215af:	b0 20                	mov    $0x20,%al
c00215b1:	e6 20                	out    %al,$0x20
  if (irq >= 0x28)
c00215b3:	83 fa 27             	cmp    $0x27,%edx
c00215b6:	7e 02                	jle    c00215ba <intr_handler+0x10d>
c00215b8:	e6 a0                	out    %al,$0xa0
      if (yield_on_return) 
c00215ba:	80 3d a0 6a 03 c0 00 	cmpb   $0x0,0xc0036aa0
c00215c1:	0f 84 1a ff ff ff    	je     c00214e1 <intr_handler+0x34>
        thread_yield (); 
c00215c7:	e8 38 fa ff ff       	call   c0021004 <thread_yield>
}
c00215cc:	e9 10 ff ff ff       	jmp    c00214e1 <intr_handler+0x34>
      ASSERT (intr_get_level () == INTR_OFF);
c00215d1:	83 ec 0c             	sub    $0xc,%esp
c00215d4:	68 20 d1 02 c0       	push   $0xc002d120
c00215d9:	68 9f cd 02 c0       	push   $0xc002cd9f
c00215de:	68 98 b7 02 c0       	push   $0xc002b798
c00215e3:	68 7c 01 00 00       	push   $0x17c
c00215e8:	68 6e d2 02 c0       	push   $0xc002d26e
c00215ed:	e8 1d 62 00 00       	call   c002780f <debug_panic>
      ASSERT (intr_context ());
c00215f2:	83 ec 0c             	sub    $0xc,%esp
c00215f5:	68 cd d1 02 c0       	push   $0xc002d1cd
c00215fa:	68 9f cd 02 c0       	push   $0xc002cd9f
c00215ff:	68 98 b7 02 c0       	push   $0xc002b798
c0021604:	68 7d 01 00 00       	push   $0x17d
c0021609:	68 6e d2 02 c0       	push   $0xc002d26e
c002160e:	e8 fc 61 00 00       	call   c002780f <debug_panic>
  ASSERT (irq >= 0x20 && irq < 0x30);
c0021613:	83 ec 0c             	sub    $0xc,%esp
c0021616:	68 31 d4 02 c0       	push   $0xc002d431
c002161b:	68 9f cd 02 c0       	push   $0xc002cd9f
c0021620:	68 80 b7 02 c0       	push   $0xc002b780
c0021625:	68 0b 01 00 00       	push   $0x10b
c002162a:	68 6e d2 02 c0       	push   $0xc002d26e
c002162f:	e8 db 61 00 00       	call   c002780f <debug_panic>

c0021634 <intr_dump_frame>:
}

/* Dumps interrupt frame F to the console, for debugging. */
void
intr_dump_frame (const struct intr_frame *f) 
{
c0021634:	56                   	push   %esi
c0021635:	53                   	push   %ebx
c0021636:	83 ec 04             	sub    $0x4,%esp
c0021639:	8b 5c 24 10          	mov    0x10(%esp),%ebx
  /* Store current value of CR2 into `cr2'.
     CR2 is the linear address of the last page fault.
     See [IA32-v2a] "MOV--Move to/from Control Registers" and
     [IA32-v3a] 5.14 "Interrupt 14--Page Fault Exception
     (#PF)". */
  asm ("movl %%cr2, %0" : "=r" (cr2));
c002163d:	0f 20 d6             	mov    %cr2,%esi

  printf ("Interrupt %#04x (%s) at eip=%p\n",
          f->vec_no, intr_names[f->vec_no], f->eip);
c0021640:	8b 43 30             	mov    0x30(%ebx),%eax
  printf ("Interrupt %#04x (%s) at eip=%p\n",
c0021643:	ff 73 3c             	pushl  0x3c(%ebx)
c0021646:	ff 34 85 c0 6e 03 c0 	pushl  -0x3ffc9140(,%eax,4)
c002164d:	50                   	push   %eax
c002164e:	68 80 d5 02 c0       	push   $0xc002d580
c0021653:	e8 09 47 00 00       	call   c0025d61 <printf>
  printf (" cr2=%08"PRIx32" error=%08"PRIx32"\n", cr2, f->error_code);
c0021658:	83 c4 0c             	add    $0xc,%esp
c002165b:	ff 73 34             	pushl  0x34(%ebx)
c002165e:	56                   	push   %esi
c002165f:	68 4b d4 02 c0       	push   $0xc002d44b
c0021664:	e8 f8 46 00 00       	call   c0025d61 <printf>
  printf (" eax=%08"PRIx32" ebx=%08"PRIx32" ecx=%08"PRIx32" edx=%08"PRIx32"\n",
c0021669:	83 c4 04             	add    $0x4,%esp
c002166c:	ff 73 14             	pushl  0x14(%ebx)
c002166f:	ff 73 18             	pushl  0x18(%ebx)
c0021672:	ff 73 10             	pushl  0x10(%ebx)
c0021675:	ff 73 1c             	pushl  0x1c(%ebx)
c0021678:	68 a0 d5 02 c0       	push   $0xc002d5a0
c002167d:	e8 df 46 00 00       	call   c0025d61 <printf>
          f->eax, f->ebx, f->ecx, f->edx);
  printf (" esi=%08"PRIx32" edi=%08"PRIx32" esp=%08"PRIx32" ebp=%08"PRIx32"\n",
c0021682:	83 c4 14             	add    $0x14,%esp
c0021685:	ff 73 08             	pushl  0x8(%ebx)
c0021688:	ff 73 48             	pushl  0x48(%ebx)
c002168b:	ff 33                	pushl  (%ebx)
c002168d:	ff 73 04             	pushl  0x4(%ebx)
c0021690:	68 c8 d5 02 c0       	push   $0xc002d5c8
c0021695:	e8 c7 46 00 00       	call   c0025d61 <printf>
          f->esi, f->edi, (uint32_t) f->esp, f->ebp);
  printf (" cs=%04"PRIx16" ds=%04"PRIx16" es=%04"PRIx16" ss=%04"PRIx16"\n",
c002169a:	83 c4 14             	add    $0x14,%esp
c002169d:	0f b7 43 4c          	movzwl 0x4c(%ebx),%eax
c00216a1:	50                   	push   %eax
c00216a2:	0f b7 43 28          	movzwl 0x28(%ebx),%eax
c00216a6:	50                   	push   %eax
c00216a7:	0f b7 43 2c          	movzwl 0x2c(%ebx),%eax
c00216ab:	50                   	push   %eax
c00216ac:	0f b7 43 40          	movzwl 0x40(%ebx),%eax
c00216b0:	50                   	push   %eax
c00216b1:	68 f0 d5 02 c0       	push   $0xc002d5f0
c00216b6:	e8 a6 46 00 00       	call   c0025d61 <printf>
          f->cs, f->ds, f->es, f->ss);
}
c00216bb:	83 c4 24             	add    $0x24,%esp
c00216be:	5b                   	pop    %ebx
c00216bf:	5e                   	pop    %esi
c00216c0:	c3                   	ret    

c00216c1 <intr_name>:

/* Returns the name of interrupt VEC. */
const char *
intr_name (uint8_t vec) 
{
  return intr_names[vec];
c00216c1:	0f b6 44 24 04       	movzbl 0x4(%esp),%eax
c00216c6:	8b 04 85 c0 6e 03 c0 	mov    -0x3ffc9140(,%eax,4),%eax
}
c00216cd:	c3                   	ret    

c00216ce <intr_entry>:
   We "fall through" to intr_exit to return from the interrupt.
*/
.func intr_entry
intr_entry:
	/* Save caller's registers. */
	pushl %ds
c00216ce:	1e                   	push   %ds
	pushl %es
c00216cf:	06                   	push   %es
	pushl %fs
c00216d0:	0f a0                	push   %fs
	pushl %gs
c00216d2:	0f a8                	push   %gs
	pushal
c00216d4:	60                   	pusha  
        
	/* Set up kernel environment. */
	cld			/* String instructions go upward. */
c00216d5:	fc                   	cld    
	mov $SEL_KDSEG, %eax	/* Initialize segment registers. */
c00216d6:	b8 10 00 00 00       	mov    $0x10,%eax
	mov %eax, %ds
c00216db:	8e d8                	mov    %eax,%ds
	mov %eax, %es
c00216dd:	8e c0                	mov    %eax,%es
	leal 56(%esp), %ebp	/* Set up frame pointer. */
c00216df:	8d 6c 24 38          	lea    0x38(%esp),%ebp

	/* Call interrupt handler. */
	pushl %esp
c00216e3:	54                   	push   %esp
.globl intr_handler
	call intr_handler
c00216e4:	e8 c4 fd ff ff       	call   c00214ad <intr_handler>
	addl $4, %esp
c00216e9:	83 c4 04             	add    $0x4,%esp

c00216ec <intr_exit>:
   userprog/process.c). */
.globl intr_exit
.func intr_exit
intr_exit:
        /* Restore caller's registers. */
	popal
c00216ec:	61                   	popa   
	popl %gs
c00216ed:	0f a9                	pop    %gs
	popl %fs
c00216ef:	0f a1                	pop    %fs
	popl %es
c00216f1:	07                   	pop    %es
	popl %ds
c00216f2:	1f                   	pop    %ds

        /* Discard `struct intr_frame' vec_no, error_code,
           frame_pointer members. */
	addl $12, %esp
c00216f3:	83 c4 0c             	add    $0xc,%esp

        /* Return to caller. */
	iret
c00216f6:	cf                   	iret   

c00216f7 <intr00_stub>:
                                                \
	.data;                                  \
	.long intr##NUMBER##_stub;

/* All the stubs. */
STUB(00, zero) STUB(01, zero) STUB(02, zero) STUB(03, zero)
c00216f7:	55                   	push   %ebp
c00216f8:	6a 00                	push   $0x0
c00216fa:	6a 00                	push   $0x0
c00216fc:	eb d0                	jmp    c00216ce <intr_entry>

c00216fe <intr01_stub>:
c00216fe:	55                   	push   %ebp
c00216ff:	6a 00                	push   $0x0
c0021701:	6a 01                	push   $0x1
c0021703:	eb c9                	jmp    c00216ce <intr_entry>

c0021705 <intr02_stub>:
c0021705:	55                   	push   %ebp
c0021706:	6a 00                	push   $0x0
c0021708:	6a 02                	push   $0x2
c002170a:	eb c2                	jmp    c00216ce <intr_entry>

c002170c <intr03_stub>:
c002170c:	55                   	push   %ebp
c002170d:	6a 00                	push   $0x0
c002170f:	6a 03                	push   $0x3
c0021711:	eb bb                	jmp    c00216ce <intr_entry>

c0021713 <intr04_stub>:
STUB(04, zero) STUB(05, zero) STUB(06, zero) STUB(07, zero)
c0021713:	55                   	push   %ebp
c0021714:	6a 00                	push   $0x0
c0021716:	6a 04                	push   $0x4
c0021718:	eb b4                	jmp    c00216ce <intr_entry>

c002171a <intr05_stub>:
c002171a:	55                   	push   %ebp
c002171b:	6a 00                	push   $0x0
c002171d:	6a 05                	push   $0x5
c002171f:	eb ad                	jmp    c00216ce <intr_entry>

c0021721 <intr06_stub>:
c0021721:	55                   	push   %ebp
c0021722:	6a 00                	push   $0x0
c0021724:	6a 06                	push   $0x6
c0021726:	eb a6                	jmp    c00216ce <intr_entry>

c0021728 <intr07_stub>:
c0021728:	55                   	push   %ebp
c0021729:	6a 00                	push   $0x0
c002172b:	6a 07                	push   $0x7
c002172d:	eb 9f                	jmp    c00216ce <intr_entry>

c002172f <intr08_stub>:
STUB(08, REAL) STUB(09, zero) STUB(0a, REAL) STUB(0b, REAL)
c002172f:	ff 34 24             	pushl  (%esp)
c0021732:	89 6c 24 04          	mov    %ebp,0x4(%esp)
c0021736:	6a 08                	push   $0x8
c0021738:	eb 94                	jmp    c00216ce <intr_entry>

c002173a <intr09_stub>:
c002173a:	55                   	push   %ebp
c002173b:	6a 00                	push   $0x0
c002173d:	6a 09                	push   $0x9
c002173f:	eb 8d                	jmp    c00216ce <intr_entry>

c0021741 <intr0a_stub>:
c0021741:	ff 34 24             	pushl  (%esp)
c0021744:	89 6c 24 04          	mov    %ebp,0x4(%esp)
c0021748:	6a 0a                	push   $0xa
c002174a:	eb 82                	jmp    c00216ce <intr_entry>

c002174c <intr0b_stub>:
c002174c:	ff 34 24             	pushl  (%esp)
c002174f:	89 6c 24 04          	mov    %ebp,0x4(%esp)
c0021753:	6a 0b                	push   $0xb
c0021755:	e9 74 ff ff ff       	jmp    c00216ce <intr_entry>

c002175a <intr0c_stub>:
STUB(0c, zero) STUB(0d, REAL) STUB(0e, REAL) STUB(0f, zero)
c002175a:	55                   	push   %ebp
c002175b:	6a 00                	push   $0x0
c002175d:	6a 0c                	push   $0xc
c002175f:	e9 6a ff ff ff       	jmp    c00216ce <intr_entry>

c0021764 <intr0d_stub>:
c0021764:	ff 34 24             	pushl  (%esp)
c0021767:	89 6c 24 04          	mov    %ebp,0x4(%esp)
c002176b:	6a 0d                	push   $0xd
c002176d:	e9 5c ff ff ff       	jmp    c00216ce <intr_entry>

c0021772 <intr0e_stub>:
c0021772:	ff 34 24             	pushl  (%esp)
c0021775:	89 6c 24 04          	mov    %ebp,0x4(%esp)
c0021779:	6a 0e                	push   $0xe
c002177b:	e9 4e ff ff ff       	jmp    c00216ce <intr_entry>

c0021780 <intr0f_stub>:
c0021780:	55                   	push   %ebp
c0021781:	6a 00                	push   $0x0
c0021783:	6a 0f                	push   $0xf
c0021785:	e9 44 ff ff ff       	jmp    c00216ce <intr_entry>

c002178a <intr10_stub>:

STUB(10, zero) STUB(11, REAL) STUB(12, zero) STUB(13, zero)
c002178a:	55                   	push   %ebp
c002178b:	6a 00                	push   $0x0
c002178d:	6a 10                	push   $0x10
c002178f:	e9 3a ff ff ff       	jmp    c00216ce <intr_entry>

c0021794 <intr11_stub>:
c0021794:	ff 34 24             	pushl  (%esp)
c0021797:	89 6c 24 04          	mov    %ebp,0x4(%esp)
c002179b:	6a 11                	push   $0x11
c002179d:	e9 2c ff ff ff       	jmp    c00216ce <intr_entry>

c00217a2 <intr12_stub>:
c00217a2:	55                   	push   %ebp
c00217a3:	6a 00                	push   $0x0
c00217a5:	6a 12                	push   $0x12
c00217a7:	e9 22 ff ff ff       	jmp    c00216ce <intr_entry>

c00217ac <intr13_stub>:
c00217ac:	55                   	push   %ebp
c00217ad:	6a 00                	push   $0x0
c00217af:	6a 13                	push   $0x13
c00217b1:	e9 18 ff ff ff       	jmp    c00216ce <intr_entry>

c00217b6 <intr14_stub>:
STUB(14, zero) STUB(15, zero) STUB(16, zero) STUB(17, zero)
c00217b6:	55                   	push   %ebp
c00217b7:	6a 00                	push   $0x0
c00217b9:	6a 14                	push   $0x14
c00217bb:	e9 0e ff ff ff       	jmp    c00216ce <intr_entry>

c00217c0 <intr15_stub>:
c00217c0:	55                   	push   %ebp
c00217c1:	6a 00                	push   $0x0
c00217c3:	6a 15                	push   $0x15
c00217c5:	e9 04 ff ff ff       	jmp    c00216ce <intr_entry>

c00217ca <intr16_stub>:
c00217ca:	55                   	push   %ebp
c00217cb:	6a 00                	push   $0x0
c00217cd:	6a 16                	push   $0x16
c00217cf:	e9 fa fe ff ff       	jmp    c00216ce <intr_entry>

c00217d4 <intr17_stub>:
c00217d4:	55                   	push   %ebp
c00217d5:	6a 00                	push   $0x0
c00217d7:	6a 17                	push   $0x17
c00217d9:	e9 f0 fe ff ff       	jmp    c00216ce <intr_entry>

c00217de <intr18_stub>:
STUB(18, REAL) STUB(19, zero) STUB(1a, REAL) STUB(1b, REAL)
c00217de:	ff 34 24             	pushl  (%esp)
c00217e1:	89 6c 24 04          	mov    %ebp,0x4(%esp)
c00217e5:	6a 18                	push   $0x18
c00217e7:	e9 e2 fe ff ff       	jmp    c00216ce <intr_entry>

c00217ec <intr19_stub>:
c00217ec:	55                   	push   %ebp
c00217ed:	6a 00                	push   $0x0
c00217ef:	6a 19                	push   $0x19
c00217f1:	e9 d8 fe ff ff       	jmp    c00216ce <intr_entry>

c00217f6 <intr1a_stub>:
c00217f6:	ff 34 24             	pushl  (%esp)
c00217f9:	89 6c 24 04          	mov    %ebp,0x4(%esp)
c00217fd:	6a 1a                	push   $0x1a
c00217ff:	e9 ca fe ff ff       	jmp    c00216ce <intr_entry>

c0021804 <intr1b_stub>:
c0021804:	ff 34 24             	pushl  (%esp)
c0021807:	89 6c 24 04          	mov    %ebp,0x4(%esp)
c002180b:	6a 1b                	push   $0x1b
c002180d:	e9 bc fe ff ff       	jmp    c00216ce <intr_entry>

c0021812 <intr1c_stub>:
STUB(1c, zero) STUB(1d, REAL) STUB(1e, REAL) STUB(1f, zero)
c0021812:	55                   	push   %ebp
c0021813:	6a 00                	push   $0x0
c0021815:	6a 1c                	push   $0x1c
c0021817:	e9 b2 fe ff ff       	jmp    c00216ce <intr_entry>

c002181c <intr1d_stub>:
c002181c:	ff 34 24             	pushl  (%esp)
c002181f:	89 6c 24 04          	mov    %ebp,0x4(%esp)
c0021823:	6a 1d                	push   $0x1d
c0021825:	e9 a4 fe ff ff       	jmp    c00216ce <intr_entry>

c002182a <intr1e_stub>:
c002182a:	ff 34 24             	pushl  (%esp)
c002182d:	89 6c 24 04          	mov    %ebp,0x4(%esp)
c0021831:	6a 1e                	push   $0x1e
c0021833:	e9 96 fe ff ff       	jmp    c00216ce <intr_entry>

c0021838 <intr1f_stub>:
c0021838:	55                   	push   %ebp
c0021839:	6a 00                	push   $0x0
c002183b:	6a 1f                	push   $0x1f
c002183d:	e9 8c fe ff ff       	jmp    c00216ce <intr_entry>

c0021842 <intr20_stub>:

STUB(20, zero) STUB(21, zero) STUB(22, zero) STUB(23, zero)
c0021842:	55                   	push   %ebp
c0021843:	6a 00                	push   $0x0
c0021845:	6a 20                	push   $0x20
c0021847:	e9 82 fe ff ff       	jmp    c00216ce <intr_entry>

c002184c <intr21_stub>:
c002184c:	55                   	push   %ebp
c002184d:	6a 00                	push   $0x0
c002184f:	6a 21                	push   $0x21
c0021851:	e9 78 fe ff ff       	jmp    c00216ce <intr_entry>

c0021856 <intr22_stub>:
c0021856:	55                   	push   %ebp
c0021857:	6a 00                	push   $0x0
c0021859:	6a 22                	push   $0x22
c002185b:	e9 6e fe ff ff       	jmp    c00216ce <intr_entry>

c0021860 <intr23_stub>:
c0021860:	55                   	push   %ebp
c0021861:	6a 00                	push   $0x0
c0021863:	6a 23                	push   $0x23
c0021865:	e9 64 fe ff ff       	jmp    c00216ce <intr_entry>

c002186a <intr24_stub>:
STUB(24, zero) STUB(25, zero) STUB(26, zero) STUB(27, zero)
c002186a:	55                   	push   %ebp
c002186b:	6a 00                	push   $0x0
c002186d:	6a 24                	push   $0x24
c002186f:	e9 5a fe ff ff       	jmp    c00216ce <intr_entry>

c0021874 <intr25_stub>:
c0021874:	55                   	push   %ebp
c0021875:	6a 00                	push   $0x0
c0021877:	6a 25                	push   $0x25
c0021879:	e9 50 fe ff ff       	jmp    c00216ce <intr_entry>

c002187e <intr26_stub>:
c002187e:	55                   	push   %ebp
c002187f:	6a 00                	push   $0x0
c0021881:	6a 26                	push   $0x26
c0021883:	e9 46 fe ff ff       	jmp    c00216ce <intr_entry>

c0021888 <intr27_stub>:
c0021888:	55                   	push   %ebp
c0021889:	6a 00                	push   $0x0
c002188b:	6a 27                	push   $0x27
c002188d:	e9 3c fe ff ff       	jmp    c00216ce <intr_entry>

c0021892 <intr28_stub>:
STUB(28, zero) STUB(29, zero) STUB(2a, zero) STUB(2b, zero)
c0021892:	55                   	push   %ebp
c0021893:	6a 00                	push   $0x0
c0021895:	6a 28                	push   $0x28
c0021897:	e9 32 fe ff ff       	jmp    c00216ce <intr_entry>

c002189c <intr29_stub>:
c002189c:	55                   	push   %ebp
c002189d:	6a 00                	push   $0x0
c002189f:	6a 29                	push   $0x29
c00218a1:	e9 28 fe ff ff       	jmp    c00216ce <intr_entry>

c00218a6 <intr2a_stub>:
c00218a6:	55                   	push   %ebp
c00218a7:	6a 00                	push   $0x0
c00218a9:	6a 2a                	push   $0x2a
c00218ab:	e9 1e fe ff ff       	jmp    c00216ce <intr_entry>

c00218b0 <intr2b_stub>:
c00218b0:	55                   	push   %ebp
c00218b1:	6a 00                	push   $0x0
c00218b3:	6a 2b                	push   $0x2b
c00218b5:	e9 14 fe ff ff       	jmp    c00216ce <intr_entry>

c00218ba <intr2c_stub>:
STUB(2c, zero) STUB(2d, zero) STUB(2e, zero) STUB(2f, zero)
c00218ba:	55                   	push   %ebp
c00218bb:	6a 00                	push   $0x0
c00218bd:	6a 2c                	push   $0x2c
c00218bf:	e9 0a fe ff ff       	jmp    c00216ce <intr_entry>

c00218c4 <intr2d_stub>:
c00218c4:	55                   	push   %ebp
c00218c5:	6a 00                	push   $0x0
c00218c7:	6a 2d                	push   $0x2d
c00218c9:	e9 00 fe ff ff       	jmp    c00216ce <intr_entry>

c00218ce <intr2e_stub>:
c00218ce:	55                   	push   %ebp
c00218cf:	6a 00                	push   $0x0
c00218d1:	6a 2e                	push   $0x2e
c00218d3:	e9 f6 fd ff ff       	jmp    c00216ce <intr_entry>

c00218d8 <intr2f_stub>:
c00218d8:	55                   	push   %ebp
c00218d9:	6a 00                	push   $0x0
c00218db:	6a 2f                	push   $0x2f
c00218dd:	e9 ec fd ff ff       	jmp    c00216ce <intr_entry>

c00218e2 <intr30_stub>:

STUB(30, zero) STUB(31, zero) STUB(32, zero) STUB(33, zero)
c00218e2:	55                   	push   %ebp
c00218e3:	6a 00                	push   $0x0
c00218e5:	6a 30                	push   $0x30
c00218e7:	e9 e2 fd ff ff       	jmp    c00216ce <intr_entry>

c00218ec <intr31_stub>:
c00218ec:	55                   	push   %ebp
c00218ed:	6a 00                	push   $0x0
c00218ef:	6a 31                	push   $0x31
c00218f1:	e9 d8 fd ff ff       	jmp    c00216ce <intr_entry>

c00218f6 <intr32_stub>:
c00218f6:	55                   	push   %ebp
c00218f7:	6a 00                	push   $0x0
c00218f9:	6a 32                	push   $0x32
c00218fb:	e9 ce fd ff ff       	jmp    c00216ce <intr_entry>

c0021900 <intr33_stub>:
c0021900:	55                   	push   %ebp
c0021901:	6a 00                	push   $0x0
c0021903:	6a 33                	push   $0x33
c0021905:	e9 c4 fd ff ff       	jmp    c00216ce <intr_entry>

c002190a <intr34_stub>:
STUB(34, zero) STUB(35, zero) STUB(36, zero) STUB(37, zero)
c002190a:	55                   	push   %ebp
c002190b:	6a 00                	push   $0x0
c002190d:	6a 34                	push   $0x34
c002190f:	e9 ba fd ff ff       	jmp    c00216ce <intr_entry>

c0021914 <intr35_stub>:
c0021914:	55                   	push   %ebp
c0021915:	6a 00                	push   $0x0
c0021917:	6a 35                	push   $0x35
c0021919:	e9 b0 fd ff ff       	jmp    c00216ce <intr_entry>

c002191e <intr36_stub>:
c002191e:	55                   	push   %ebp
c002191f:	6a 00                	push   $0x0
c0021921:	6a 36                	push   $0x36
c0021923:	e9 a6 fd ff ff       	jmp    c00216ce <intr_entry>

c0021928 <intr37_stub>:
c0021928:	55                   	push   %ebp
c0021929:	6a 00                	push   $0x0
c002192b:	6a 37                	push   $0x37
c002192d:	e9 9c fd ff ff       	jmp    c00216ce <intr_entry>

c0021932 <intr38_stub>:
STUB(38, zero) STUB(39, zero) STUB(3a, zero) STUB(3b, zero)
c0021932:	55                   	push   %ebp
c0021933:	6a 00                	push   $0x0
c0021935:	6a 38                	push   $0x38
c0021937:	e9 92 fd ff ff       	jmp    c00216ce <intr_entry>

c002193c <intr39_stub>:
c002193c:	55                   	push   %ebp
c002193d:	6a 00                	push   $0x0
c002193f:	6a 39                	push   $0x39
c0021941:	e9 88 fd ff ff       	jmp    c00216ce <intr_entry>

c0021946 <intr3a_stub>:
c0021946:	55                   	push   %ebp
c0021947:	6a 00                	push   $0x0
c0021949:	6a 3a                	push   $0x3a
c002194b:	e9 7e fd ff ff       	jmp    c00216ce <intr_entry>

c0021950 <intr3b_stub>:
c0021950:	55                   	push   %ebp
c0021951:	6a 00                	push   $0x0
c0021953:	6a 3b                	push   $0x3b
c0021955:	e9 74 fd ff ff       	jmp    c00216ce <intr_entry>

c002195a <intr3c_stub>:
STUB(3c, zero) STUB(3d, zero) STUB(3e, zero) STUB(3f, zero)
c002195a:	55                   	push   %ebp
c002195b:	6a 00                	push   $0x0
c002195d:	6a 3c                	push   $0x3c
c002195f:	e9 6a fd ff ff       	jmp    c00216ce <intr_entry>

c0021964 <intr3d_stub>:
c0021964:	55                   	push   %ebp
c0021965:	6a 00                	push   $0x0
c0021967:	6a 3d                	push   $0x3d
c0021969:	e9 60 fd ff ff       	jmp    c00216ce <intr_entry>

c002196e <intr3e_stub>:
c002196e:	55                   	push   %ebp
c002196f:	6a 00                	push   $0x0
c0021971:	6a 3e                	push   $0x3e
c0021973:	e9 56 fd ff ff       	jmp    c00216ce <intr_entry>

c0021978 <intr3f_stub>:
c0021978:	55                   	push   %ebp
c0021979:	6a 00                	push   $0x0
c002197b:	6a 3f                	push   $0x3f
c002197d:	e9 4c fd ff ff       	jmp    c00216ce <intr_entry>

c0021982 <intr40_stub>:

STUB(40, zero) STUB(41, zero) STUB(42, zero) STUB(43, zero)
c0021982:	55                   	push   %ebp
c0021983:	6a 00                	push   $0x0
c0021985:	6a 40                	push   $0x40
c0021987:	e9 42 fd ff ff       	jmp    c00216ce <intr_entry>

c002198c <intr41_stub>:
c002198c:	55                   	push   %ebp
c002198d:	6a 00                	push   $0x0
c002198f:	6a 41                	push   $0x41
c0021991:	e9 38 fd ff ff       	jmp    c00216ce <intr_entry>

c0021996 <intr42_stub>:
c0021996:	55                   	push   %ebp
c0021997:	6a 00                	push   $0x0
c0021999:	6a 42                	push   $0x42
c002199b:	e9 2e fd ff ff       	jmp    c00216ce <intr_entry>

c00219a0 <intr43_stub>:
c00219a0:	55                   	push   %ebp
c00219a1:	6a 00                	push   $0x0
c00219a3:	6a 43                	push   $0x43
c00219a5:	e9 24 fd ff ff       	jmp    c00216ce <intr_entry>

c00219aa <intr44_stub>:
STUB(44, zero) STUB(45, zero) STUB(46, zero) STUB(47, zero)
c00219aa:	55                   	push   %ebp
c00219ab:	6a 00                	push   $0x0
c00219ad:	6a 44                	push   $0x44
c00219af:	e9 1a fd ff ff       	jmp    c00216ce <intr_entry>

c00219b4 <intr45_stub>:
c00219b4:	55                   	push   %ebp
c00219b5:	6a 00                	push   $0x0
c00219b7:	6a 45                	push   $0x45
c00219b9:	e9 10 fd ff ff       	jmp    c00216ce <intr_entry>

c00219be <intr46_stub>:
c00219be:	55                   	push   %ebp
c00219bf:	6a 00                	push   $0x0
c00219c1:	6a 46                	push   $0x46
c00219c3:	e9 06 fd ff ff       	jmp    c00216ce <intr_entry>

c00219c8 <intr47_stub>:
c00219c8:	55                   	push   %ebp
c00219c9:	6a 00                	push   $0x0
c00219cb:	6a 47                	push   $0x47
c00219cd:	e9 fc fc ff ff       	jmp    c00216ce <intr_entry>

c00219d2 <intr48_stub>:
STUB(48, zero) STUB(49, zero) STUB(4a, zero) STUB(4b, zero)
c00219d2:	55                   	push   %ebp
c00219d3:	6a 00                	push   $0x0
c00219d5:	6a 48                	push   $0x48
c00219d7:	e9 f2 fc ff ff       	jmp    c00216ce <intr_entry>

c00219dc <intr49_stub>:
c00219dc:	55                   	push   %ebp
c00219dd:	6a 00                	push   $0x0
c00219df:	6a 49                	push   $0x49
c00219e1:	e9 e8 fc ff ff       	jmp    c00216ce <intr_entry>

c00219e6 <intr4a_stub>:
c00219e6:	55                   	push   %ebp
c00219e7:	6a 00                	push   $0x0
c00219e9:	6a 4a                	push   $0x4a
c00219eb:	e9 de fc ff ff       	jmp    c00216ce <intr_entry>

c00219f0 <intr4b_stub>:
c00219f0:	55                   	push   %ebp
c00219f1:	6a 00                	push   $0x0
c00219f3:	6a 4b                	push   $0x4b
c00219f5:	e9 d4 fc ff ff       	jmp    c00216ce <intr_entry>

c00219fa <intr4c_stub>:
STUB(4c, zero) STUB(4d, zero) STUB(4e, zero) STUB(4f, zero)
c00219fa:	55                   	push   %ebp
c00219fb:	6a 00                	push   $0x0
c00219fd:	6a 4c                	push   $0x4c
c00219ff:	e9 ca fc ff ff       	jmp    c00216ce <intr_entry>

c0021a04 <intr4d_stub>:
c0021a04:	55                   	push   %ebp
c0021a05:	6a 00                	push   $0x0
c0021a07:	6a 4d                	push   $0x4d
c0021a09:	e9 c0 fc ff ff       	jmp    c00216ce <intr_entry>

c0021a0e <intr4e_stub>:
c0021a0e:	55                   	push   %ebp
c0021a0f:	6a 00                	push   $0x0
c0021a11:	6a 4e                	push   $0x4e
c0021a13:	e9 b6 fc ff ff       	jmp    c00216ce <intr_entry>

c0021a18 <intr4f_stub>:
c0021a18:	55                   	push   %ebp
c0021a19:	6a 00                	push   $0x0
c0021a1b:	6a 4f                	push   $0x4f
c0021a1d:	e9 ac fc ff ff       	jmp    c00216ce <intr_entry>

c0021a22 <intr50_stub>:

STUB(50, zero) STUB(51, zero) STUB(52, zero) STUB(53, zero)
c0021a22:	55                   	push   %ebp
c0021a23:	6a 00                	push   $0x0
c0021a25:	6a 50                	push   $0x50
c0021a27:	e9 a2 fc ff ff       	jmp    c00216ce <intr_entry>

c0021a2c <intr51_stub>:
c0021a2c:	55                   	push   %ebp
c0021a2d:	6a 00                	push   $0x0
c0021a2f:	6a 51                	push   $0x51
c0021a31:	e9 98 fc ff ff       	jmp    c00216ce <intr_entry>

c0021a36 <intr52_stub>:
c0021a36:	55                   	push   %ebp
c0021a37:	6a 00                	push   $0x0
c0021a39:	6a 52                	push   $0x52
c0021a3b:	e9 8e fc ff ff       	jmp    c00216ce <intr_entry>

c0021a40 <intr53_stub>:
c0021a40:	55                   	push   %ebp
c0021a41:	6a 00                	push   $0x0
c0021a43:	6a 53                	push   $0x53
c0021a45:	e9 84 fc ff ff       	jmp    c00216ce <intr_entry>

c0021a4a <intr54_stub>:
STUB(54, zero) STUB(55, zero) STUB(56, zero) STUB(57, zero)
c0021a4a:	55                   	push   %ebp
c0021a4b:	6a 00                	push   $0x0
c0021a4d:	6a 54                	push   $0x54
c0021a4f:	e9 7a fc ff ff       	jmp    c00216ce <intr_entry>

c0021a54 <intr55_stub>:
c0021a54:	55                   	push   %ebp
c0021a55:	6a 00                	push   $0x0
c0021a57:	6a 55                	push   $0x55
c0021a59:	e9 70 fc ff ff       	jmp    c00216ce <intr_entry>

c0021a5e <intr56_stub>:
c0021a5e:	55                   	push   %ebp
c0021a5f:	6a 00                	push   $0x0
c0021a61:	6a 56                	push   $0x56
c0021a63:	e9 66 fc ff ff       	jmp    c00216ce <intr_entry>

c0021a68 <intr57_stub>:
c0021a68:	55                   	push   %ebp
c0021a69:	6a 00                	push   $0x0
c0021a6b:	6a 57                	push   $0x57
c0021a6d:	e9 5c fc ff ff       	jmp    c00216ce <intr_entry>

c0021a72 <intr58_stub>:
STUB(58, zero) STUB(59, zero) STUB(5a, zero) STUB(5b, zero)
c0021a72:	55                   	push   %ebp
c0021a73:	6a 00                	push   $0x0
c0021a75:	6a 58                	push   $0x58
c0021a77:	e9 52 fc ff ff       	jmp    c00216ce <intr_entry>

c0021a7c <intr59_stub>:
c0021a7c:	55                   	push   %ebp
c0021a7d:	6a 00                	push   $0x0
c0021a7f:	6a 59                	push   $0x59
c0021a81:	e9 48 fc ff ff       	jmp    c00216ce <intr_entry>

c0021a86 <intr5a_stub>:
c0021a86:	55                   	push   %ebp
c0021a87:	6a 00                	push   $0x0
c0021a89:	6a 5a                	push   $0x5a
c0021a8b:	e9 3e fc ff ff       	jmp    c00216ce <intr_entry>

c0021a90 <intr5b_stub>:
c0021a90:	55                   	push   %ebp
c0021a91:	6a 00                	push   $0x0
c0021a93:	6a 5b                	push   $0x5b
c0021a95:	e9 34 fc ff ff       	jmp    c00216ce <intr_entry>

c0021a9a <intr5c_stub>:
STUB(5c, zero) STUB(5d, zero) STUB(5e, zero) STUB(5f, zero)
c0021a9a:	55                   	push   %ebp
c0021a9b:	6a 00                	push   $0x0
c0021a9d:	6a 5c                	push   $0x5c
c0021a9f:	e9 2a fc ff ff       	jmp    c00216ce <intr_entry>

c0021aa4 <intr5d_stub>:
c0021aa4:	55                   	push   %ebp
c0021aa5:	6a 00                	push   $0x0
c0021aa7:	6a 5d                	push   $0x5d
c0021aa9:	e9 20 fc ff ff       	jmp    c00216ce <intr_entry>

c0021aae <intr5e_stub>:
c0021aae:	55                   	push   %ebp
c0021aaf:	6a 00                	push   $0x0
c0021ab1:	6a 5e                	push   $0x5e
c0021ab3:	e9 16 fc ff ff       	jmp    c00216ce <intr_entry>

c0021ab8 <intr5f_stub>:
c0021ab8:	55                   	push   %ebp
c0021ab9:	6a 00                	push   $0x0
c0021abb:	6a 5f                	push   $0x5f
c0021abd:	e9 0c fc ff ff       	jmp    c00216ce <intr_entry>

c0021ac2 <intr60_stub>:

STUB(60, zero) STUB(61, zero) STUB(62, zero) STUB(63, zero)
c0021ac2:	55                   	push   %ebp
c0021ac3:	6a 00                	push   $0x0
c0021ac5:	6a 60                	push   $0x60
c0021ac7:	e9 02 fc ff ff       	jmp    c00216ce <intr_entry>

c0021acc <intr61_stub>:
c0021acc:	55                   	push   %ebp
c0021acd:	6a 00                	push   $0x0
c0021acf:	6a 61                	push   $0x61
c0021ad1:	e9 f8 fb ff ff       	jmp    c00216ce <intr_entry>

c0021ad6 <intr62_stub>:
c0021ad6:	55                   	push   %ebp
c0021ad7:	6a 00                	push   $0x0
c0021ad9:	6a 62                	push   $0x62
c0021adb:	e9 ee fb ff ff       	jmp    c00216ce <intr_entry>

c0021ae0 <intr63_stub>:
c0021ae0:	55                   	push   %ebp
c0021ae1:	6a 00                	push   $0x0
c0021ae3:	6a 63                	push   $0x63
c0021ae5:	e9 e4 fb ff ff       	jmp    c00216ce <intr_entry>

c0021aea <intr64_stub>:
STUB(64, zero) STUB(65, zero) STUB(66, zero) STUB(67, zero)
c0021aea:	55                   	push   %ebp
c0021aeb:	6a 00                	push   $0x0
c0021aed:	6a 64                	push   $0x64
c0021aef:	e9 da fb ff ff       	jmp    c00216ce <intr_entry>

c0021af4 <intr65_stub>:
c0021af4:	55                   	push   %ebp
c0021af5:	6a 00                	push   $0x0
c0021af7:	6a 65                	push   $0x65
c0021af9:	e9 d0 fb ff ff       	jmp    c00216ce <intr_entry>

c0021afe <intr66_stub>:
c0021afe:	55                   	push   %ebp
c0021aff:	6a 00                	push   $0x0
c0021b01:	6a 66                	push   $0x66
c0021b03:	e9 c6 fb ff ff       	jmp    c00216ce <intr_entry>

c0021b08 <intr67_stub>:
c0021b08:	55                   	push   %ebp
c0021b09:	6a 00                	push   $0x0
c0021b0b:	6a 67                	push   $0x67
c0021b0d:	e9 bc fb ff ff       	jmp    c00216ce <intr_entry>

c0021b12 <intr68_stub>:
STUB(68, zero) STUB(69, zero) STUB(6a, zero) STUB(6b, zero)
c0021b12:	55                   	push   %ebp
c0021b13:	6a 00                	push   $0x0
c0021b15:	6a 68                	push   $0x68
c0021b17:	e9 b2 fb ff ff       	jmp    c00216ce <intr_entry>

c0021b1c <intr69_stub>:
c0021b1c:	55                   	push   %ebp
c0021b1d:	6a 00                	push   $0x0
c0021b1f:	6a 69                	push   $0x69
c0021b21:	e9 a8 fb ff ff       	jmp    c00216ce <intr_entry>

c0021b26 <intr6a_stub>:
c0021b26:	55                   	push   %ebp
c0021b27:	6a 00                	push   $0x0
c0021b29:	6a 6a                	push   $0x6a
c0021b2b:	e9 9e fb ff ff       	jmp    c00216ce <intr_entry>

c0021b30 <intr6b_stub>:
c0021b30:	55                   	push   %ebp
c0021b31:	6a 00                	push   $0x0
c0021b33:	6a 6b                	push   $0x6b
c0021b35:	e9 94 fb ff ff       	jmp    c00216ce <intr_entry>

c0021b3a <intr6c_stub>:
STUB(6c, zero) STUB(6d, zero) STUB(6e, zero) STUB(6f, zero)
c0021b3a:	55                   	push   %ebp
c0021b3b:	6a 00                	push   $0x0
c0021b3d:	6a 6c                	push   $0x6c
c0021b3f:	e9 8a fb ff ff       	jmp    c00216ce <intr_entry>

c0021b44 <intr6d_stub>:
c0021b44:	55                   	push   %ebp
c0021b45:	6a 00                	push   $0x0
c0021b47:	6a 6d                	push   $0x6d
c0021b49:	e9 80 fb ff ff       	jmp    c00216ce <intr_entry>

c0021b4e <intr6e_stub>:
c0021b4e:	55                   	push   %ebp
c0021b4f:	6a 00                	push   $0x0
c0021b51:	6a 6e                	push   $0x6e
c0021b53:	e9 76 fb ff ff       	jmp    c00216ce <intr_entry>

c0021b58 <intr6f_stub>:
c0021b58:	55                   	push   %ebp
c0021b59:	6a 00                	push   $0x0
c0021b5b:	6a 6f                	push   $0x6f
c0021b5d:	e9 6c fb ff ff       	jmp    c00216ce <intr_entry>

c0021b62 <intr70_stub>:

STUB(70, zero) STUB(71, zero) STUB(72, zero) STUB(73, zero)
c0021b62:	55                   	push   %ebp
c0021b63:	6a 00                	push   $0x0
c0021b65:	6a 70                	push   $0x70
c0021b67:	e9 62 fb ff ff       	jmp    c00216ce <intr_entry>

c0021b6c <intr71_stub>:
c0021b6c:	55                   	push   %ebp
c0021b6d:	6a 00                	push   $0x0
c0021b6f:	6a 71                	push   $0x71
c0021b71:	e9 58 fb ff ff       	jmp    c00216ce <intr_entry>

c0021b76 <intr72_stub>:
c0021b76:	55                   	push   %ebp
c0021b77:	6a 00                	push   $0x0
c0021b79:	6a 72                	push   $0x72
c0021b7b:	e9 4e fb ff ff       	jmp    c00216ce <intr_entry>

c0021b80 <intr73_stub>:
c0021b80:	55                   	push   %ebp
c0021b81:	6a 00                	push   $0x0
c0021b83:	6a 73                	push   $0x73
c0021b85:	e9 44 fb ff ff       	jmp    c00216ce <intr_entry>

c0021b8a <intr74_stub>:
STUB(74, zero) STUB(75, zero) STUB(76, zero) STUB(77, zero)
c0021b8a:	55                   	push   %ebp
c0021b8b:	6a 00                	push   $0x0
c0021b8d:	6a 74                	push   $0x74
c0021b8f:	e9 3a fb ff ff       	jmp    c00216ce <intr_entry>

c0021b94 <intr75_stub>:
c0021b94:	55                   	push   %ebp
c0021b95:	6a 00                	push   $0x0
c0021b97:	6a 75                	push   $0x75
c0021b99:	e9 30 fb ff ff       	jmp    c00216ce <intr_entry>

c0021b9e <intr76_stub>:
c0021b9e:	55                   	push   %ebp
c0021b9f:	6a 00                	push   $0x0
c0021ba1:	6a 76                	push   $0x76
c0021ba3:	e9 26 fb ff ff       	jmp    c00216ce <intr_entry>

c0021ba8 <intr77_stub>:
c0021ba8:	55                   	push   %ebp
c0021ba9:	6a 00                	push   $0x0
c0021bab:	6a 77                	push   $0x77
c0021bad:	e9 1c fb ff ff       	jmp    c00216ce <intr_entry>

c0021bb2 <intr78_stub>:
STUB(78, zero) STUB(79, zero) STUB(7a, zero) STUB(7b, zero)
c0021bb2:	55                   	push   %ebp
c0021bb3:	6a 00                	push   $0x0
c0021bb5:	6a 78                	push   $0x78
c0021bb7:	e9 12 fb ff ff       	jmp    c00216ce <intr_entry>

c0021bbc <intr79_stub>:
c0021bbc:	55                   	push   %ebp
c0021bbd:	6a 00                	push   $0x0
c0021bbf:	6a 79                	push   $0x79
c0021bc1:	e9 08 fb ff ff       	jmp    c00216ce <intr_entry>

c0021bc6 <intr7a_stub>:
c0021bc6:	55                   	push   %ebp
c0021bc7:	6a 00                	push   $0x0
c0021bc9:	6a 7a                	push   $0x7a
c0021bcb:	e9 fe fa ff ff       	jmp    c00216ce <intr_entry>

c0021bd0 <intr7b_stub>:
c0021bd0:	55                   	push   %ebp
c0021bd1:	6a 00                	push   $0x0
c0021bd3:	6a 7b                	push   $0x7b
c0021bd5:	e9 f4 fa ff ff       	jmp    c00216ce <intr_entry>

c0021bda <intr7c_stub>:
STUB(7c, zero) STUB(7d, zero) STUB(7e, zero) STUB(7f, zero)
c0021bda:	55                   	push   %ebp
c0021bdb:	6a 00                	push   $0x0
c0021bdd:	6a 7c                	push   $0x7c
c0021bdf:	e9 ea fa ff ff       	jmp    c00216ce <intr_entry>

c0021be4 <intr7d_stub>:
c0021be4:	55                   	push   %ebp
c0021be5:	6a 00                	push   $0x0
c0021be7:	6a 7d                	push   $0x7d
c0021be9:	e9 e0 fa ff ff       	jmp    c00216ce <intr_entry>

c0021bee <intr7e_stub>:
c0021bee:	55                   	push   %ebp
c0021bef:	6a 00                	push   $0x0
c0021bf1:	6a 7e                	push   $0x7e
c0021bf3:	e9 d6 fa ff ff       	jmp    c00216ce <intr_entry>

c0021bf8 <intr7f_stub>:
c0021bf8:	55                   	push   %ebp
c0021bf9:	6a 00                	push   $0x0
c0021bfb:	6a 7f                	push   $0x7f
c0021bfd:	e9 cc fa ff ff       	jmp    c00216ce <intr_entry>

c0021c02 <intr80_stub>:

STUB(80, zero) STUB(81, zero) STUB(82, zero) STUB(83, zero)
c0021c02:	55                   	push   %ebp
c0021c03:	6a 00                	push   $0x0
c0021c05:	68 80 00 00 00       	push   $0x80
c0021c0a:	e9 bf fa ff ff       	jmp    c00216ce <intr_entry>

c0021c0f <intr81_stub>:
c0021c0f:	55                   	push   %ebp
c0021c10:	6a 00                	push   $0x0
c0021c12:	68 81 00 00 00       	push   $0x81
c0021c17:	e9 b2 fa ff ff       	jmp    c00216ce <intr_entry>

c0021c1c <intr82_stub>:
c0021c1c:	55                   	push   %ebp
c0021c1d:	6a 00                	push   $0x0
c0021c1f:	68 82 00 00 00       	push   $0x82
c0021c24:	e9 a5 fa ff ff       	jmp    c00216ce <intr_entry>

c0021c29 <intr83_stub>:
c0021c29:	55                   	push   %ebp
c0021c2a:	6a 00                	push   $0x0
c0021c2c:	68 83 00 00 00       	push   $0x83
c0021c31:	e9 98 fa ff ff       	jmp    c00216ce <intr_entry>

c0021c36 <intr84_stub>:
STUB(84, zero) STUB(85, zero) STUB(86, zero) STUB(87, zero)
c0021c36:	55                   	push   %ebp
c0021c37:	6a 00                	push   $0x0
c0021c39:	68 84 00 00 00       	push   $0x84
c0021c3e:	e9 8b fa ff ff       	jmp    c00216ce <intr_entry>

c0021c43 <intr85_stub>:
c0021c43:	55                   	push   %ebp
c0021c44:	6a 00                	push   $0x0
c0021c46:	68 85 00 00 00       	push   $0x85
c0021c4b:	e9 7e fa ff ff       	jmp    c00216ce <intr_entry>

c0021c50 <intr86_stub>:
c0021c50:	55                   	push   %ebp
c0021c51:	6a 00                	push   $0x0
c0021c53:	68 86 00 00 00       	push   $0x86
c0021c58:	e9 71 fa ff ff       	jmp    c00216ce <intr_entry>

c0021c5d <intr87_stub>:
c0021c5d:	55                   	push   %ebp
c0021c5e:	6a 00                	push   $0x0
c0021c60:	68 87 00 00 00       	push   $0x87
c0021c65:	e9 64 fa ff ff       	jmp    c00216ce <intr_entry>

c0021c6a <intr88_stub>:
STUB(88, zero) STUB(89, zero) STUB(8a, zero) STUB(8b, zero)
c0021c6a:	55                   	push   %ebp
c0021c6b:	6a 00                	push   $0x0
c0021c6d:	68 88 00 00 00       	push   $0x88
c0021c72:	e9 57 fa ff ff       	jmp    c00216ce <intr_entry>

c0021c77 <intr89_stub>:
c0021c77:	55                   	push   %ebp
c0021c78:	6a 00                	push   $0x0
c0021c7a:	68 89 00 00 00       	push   $0x89
c0021c7f:	e9 4a fa ff ff       	jmp    c00216ce <intr_entry>

c0021c84 <intr8a_stub>:
c0021c84:	55                   	push   %ebp
c0021c85:	6a 00                	push   $0x0
c0021c87:	68 8a 00 00 00       	push   $0x8a
c0021c8c:	e9 3d fa ff ff       	jmp    c00216ce <intr_entry>

c0021c91 <intr8b_stub>:
c0021c91:	55                   	push   %ebp
c0021c92:	6a 00                	push   $0x0
c0021c94:	68 8b 00 00 00       	push   $0x8b
c0021c99:	e9 30 fa ff ff       	jmp    c00216ce <intr_entry>

c0021c9e <intr8c_stub>:
STUB(8c, zero) STUB(8d, zero) STUB(8e, zero) STUB(8f, zero)
c0021c9e:	55                   	push   %ebp
c0021c9f:	6a 00                	push   $0x0
c0021ca1:	68 8c 00 00 00       	push   $0x8c
c0021ca6:	e9 23 fa ff ff       	jmp    c00216ce <intr_entry>

c0021cab <intr8d_stub>:
c0021cab:	55                   	push   %ebp
c0021cac:	6a 00                	push   $0x0
c0021cae:	68 8d 00 00 00       	push   $0x8d
c0021cb3:	e9 16 fa ff ff       	jmp    c00216ce <intr_entry>

c0021cb8 <intr8e_stub>:
c0021cb8:	55                   	push   %ebp
c0021cb9:	6a 00                	push   $0x0
c0021cbb:	68 8e 00 00 00       	push   $0x8e
c0021cc0:	e9 09 fa ff ff       	jmp    c00216ce <intr_entry>

c0021cc5 <intr8f_stub>:
c0021cc5:	55                   	push   %ebp
c0021cc6:	6a 00                	push   $0x0
c0021cc8:	68 8f 00 00 00       	push   $0x8f
c0021ccd:	e9 fc f9 ff ff       	jmp    c00216ce <intr_entry>

c0021cd2 <intr90_stub>:

STUB(90, zero) STUB(91, zero) STUB(92, zero) STUB(93, zero)
c0021cd2:	55                   	push   %ebp
c0021cd3:	6a 00                	push   $0x0
c0021cd5:	68 90 00 00 00       	push   $0x90
c0021cda:	e9 ef f9 ff ff       	jmp    c00216ce <intr_entry>

c0021cdf <intr91_stub>:
c0021cdf:	55                   	push   %ebp
c0021ce0:	6a 00                	push   $0x0
c0021ce2:	68 91 00 00 00       	push   $0x91
c0021ce7:	e9 e2 f9 ff ff       	jmp    c00216ce <intr_entry>

c0021cec <intr92_stub>:
c0021cec:	55                   	push   %ebp
c0021ced:	6a 00                	push   $0x0
c0021cef:	68 92 00 00 00       	push   $0x92
c0021cf4:	e9 d5 f9 ff ff       	jmp    c00216ce <intr_entry>

c0021cf9 <intr93_stub>:
c0021cf9:	55                   	push   %ebp
c0021cfa:	6a 00                	push   $0x0
c0021cfc:	68 93 00 00 00       	push   $0x93
c0021d01:	e9 c8 f9 ff ff       	jmp    c00216ce <intr_entry>

c0021d06 <intr94_stub>:
STUB(94, zero) STUB(95, zero) STUB(96, zero) STUB(97, zero)
c0021d06:	55                   	push   %ebp
c0021d07:	6a 00                	push   $0x0
c0021d09:	68 94 00 00 00       	push   $0x94
c0021d0e:	e9 bb f9 ff ff       	jmp    c00216ce <intr_entry>

c0021d13 <intr95_stub>:
c0021d13:	55                   	push   %ebp
c0021d14:	6a 00                	push   $0x0
c0021d16:	68 95 00 00 00       	push   $0x95
c0021d1b:	e9 ae f9 ff ff       	jmp    c00216ce <intr_entry>

c0021d20 <intr96_stub>:
c0021d20:	55                   	push   %ebp
c0021d21:	6a 00                	push   $0x0
c0021d23:	68 96 00 00 00       	push   $0x96
c0021d28:	e9 a1 f9 ff ff       	jmp    c00216ce <intr_entry>

c0021d2d <intr97_stub>:
c0021d2d:	55                   	push   %ebp
c0021d2e:	6a 00                	push   $0x0
c0021d30:	68 97 00 00 00       	push   $0x97
c0021d35:	e9 94 f9 ff ff       	jmp    c00216ce <intr_entry>

c0021d3a <intr98_stub>:
STUB(98, zero) STUB(99, zero) STUB(9a, zero) STUB(9b, zero)
c0021d3a:	55                   	push   %ebp
c0021d3b:	6a 00                	push   $0x0
c0021d3d:	68 98 00 00 00       	push   $0x98
c0021d42:	e9 87 f9 ff ff       	jmp    c00216ce <intr_entry>

c0021d47 <intr99_stub>:
c0021d47:	55                   	push   %ebp
c0021d48:	6a 00                	push   $0x0
c0021d4a:	68 99 00 00 00       	push   $0x99
c0021d4f:	e9 7a f9 ff ff       	jmp    c00216ce <intr_entry>

c0021d54 <intr9a_stub>:
c0021d54:	55                   	push   %ebp
c0021d55:	6a 00                	push   $0x0
c0021d57:	68 9a 00 00 00       	push   $0x9a
c0021d5c:	e9 6d f9 ff ff       	jmp    c00216ce <intr_entry>

c0021d61 <intr9b_stub>:
c0021d61:	55                   	push   %ebp
c0021d62:	6a 00                	push   $0x0
c0021d64:	68 9b 00 00 00       	push   $0x9b
c0021d69:	e9 60 f9 ff ff       	jmp    c00216ce <intr_entry>

c0021d6e <intr9c_stub>:
STUB(9c, zero) STUB(9d, zero) STUB(9e, zero) STUB(9f, zero)
c0021d6e:	55                   	push   %ebp
c0021d6f:	6a 00                	push   $0x0
c0021d71:	68 9c 00 00 00       	push   $0x9c
c0021d76:	e9 53 f9 ff ff       	jmp    c00216ce <intr_entry>

c0021d7b <intr9d_stub>:
c0021d7b:	55                   	push   %ebp
c0021d7c:	6a 00                	push   $0x0
c0021d7e:	68 9d 00 00 00       	push   $0x9d
c0021d83:	e9 46 f9 ff ff       	jmp    c00216ce <intr_entry>

c0021d88 <intr9e_stub>:
c0021d88:	55                   	push   %ebp
c0021d89:	6a 00                	push   $0x0
c0021d8b:	68 9e 00 00 00       	push   $0x9e
c0021d90:	e9 39 f9 ff ff       	jmp    c00216ce <intr_entry>

c0021d95 <intr9f_stub>:
c0021d95:	55                   	push   %ebp
c0021d96:	6a 00                	push   $0x0
c0021d98:	68 9f 00 00 00       	push   $0x9f
c0021d9d:	e9 2c f9 ff ff       	jmp    c00216ce <intr_entry>

c0021da2 <intra0_stub>:

STUB(a0, zero) STUB(a1, zero) STUB(a2, zero) STUB(a3, zero)
c0021da2:	55                   	push   %ebp
c0021da3:	6a 00                	push   $0x0
c0021da5:	68 a0 00 00 00       	push   $0xa0
c0021daa:	e9 1f f9 ff ff       	jmp    c00216ce <intr_entry>

c0021daf <intra1_stub>:
c0021daf:	55                   	push   %ebp
c0021db0:	6a 00                	push   $0x0
c0021db2:	68 a1 00 00 00       	push   $0xa1
c0021db7:	e9 12 f9 ff ff       	jmp    c00216ce <intr_entry>

c0021dbc <intra2_stub>:
c0021dbc:	55                   	push   %ebp
c0021dbd:	6a 00                	push   $0x0
c0021dbf:	68 a2 00 00 00       	push   $0xa2
c0021dc4:	e9 05 f9 ff ff       	jmp    c00216ce <intr_entry>

c0021dc9 <intra3_stub>:
c0021dc9:	55                   	push   %ebp
c0021dca:	6a 00                	push   $0x0
c0021dcc:	68 a3 00 00 00       	push   $0xa3
c0021dd1:	e9 f8 f8 ff ff       	jmp    c00216ce <intr_entry>

c0021dd6 <intra4_stub>:
STUB(a4, zero) STUB(a5, zero) STUB(a6, zero) STUB(a7, zero)
c0021dd6:	55                   	push   %ebp
c0021dd7:	6a 00                	push   $0x0
c0021dd9:	68 a4 00 00 00       	push   $0xa4
c0021dde:	e9 eb f8 ff ff       	jmp    c00216ce <intr_entry>

c0021de3 <intra5_stub>:
c0021de3:	55                   	push   %ebp
c0021de4:	6a 00                	push   $0x0
c0021de6:	68 a5 00 00 00       	push   $0xa5
c0021deb:	e9 de f8 ff ff       	jmp    c00216ce <intr_entry>

c0021df0 <intra6_stub>:
c0021df0:	55                   	push   %ebp
c0021df1:	6a 00                	push   $0x0
c0021df3:	68 a6 00 00 00       	push   $0xa6
c0021df8:	e9 d1 f8 ff ff       	jmp    c00216ce <intr_entry>

c0021dfd <intra7_stub>:
c0021dfd:	55                   	push   %ebp
c0021dfe:	6a 00                	push   $0x0
c0021e00:	68 a7 00 00 00       	push   $0xa7
c0021e05:	e9 c4 f8 ff ff       	jmp    c00216ce <intr_entry>

c0021e0a <intra8_stub>:
STUB(a8, zero) STUB(a9, zero) STUB(aa, zero) STUB(ab, zero)
c0021e0a:	55                   	push   %ebp
c0021e0b:	6a 00                	push   $0x0
c0021e0d:	68 a8 00 00 00       	push   $0xa8
c0021e12:	e9 b7 f8 ff ff       	jmp    c00216ce <intr_entry>

c0021e17 <intra9_stub>:
c0021e17:	55                   	push   %ebp
c0021e18:	6a 00                	push   $0x0
c0021e1a:	68 a9 00 00 00       	push   $0xa9
c0021e1f:	e9 aa f8 ff ff       	jmp    c00216ce <intr_entry>

c0021e24 <intraa_stub>:
c0021e24:	55                   	push   %ebp
c0021e25:	6a 00                	push   $0x0
c0021e27:	68 aa 00 00 00       	push   $0xaa
c0021e2c:	e9 9d f8 ff ff       	jmp    c00216ce <intr_entry>

c0021e31 <intrab_stub>:
c0021e31:	55                   	push   %ebp
c0021e32:	6a 00                	push   $0x0
c0021e34:	68 ab 00 00 00       	push   $0xab
c0021e39:	e9 90 f8 ff ff       	jmp    c00216ce <intr_entry>

c0021e3e <intrac_stub>:
STUB(ac, zero) STUB(ad, zero) STUB(ae, zero) STUB(af, zero)
c0021e3e:	55                   	push   %ebp
c0021e3f:	6a 00                	push   $0x0
c0021e41:	68 ac 00 00 00       	push   $0xac
c0021e46:	e9 83 f8 ff ff       	jmp    c00216ce <intr_entry>

c0021e4b <intrad_stub>:
c0021e4b:	55                   	push   %ebp
c0021e4c:	6a 00                	push   $0x0
c0021e4e:	68 ad 00 00 00       	push   $0xad
c0021e53:	e9 76 f8 ff ff       	jmp    c00216ce <intr_entry>

c0021e58 <intrae_stub>:
c0021e58:	55                   	push   %ebp
c0021e59:	6a 00                	push   $0x0
c0021e5b:	68 ae 00 00 00       	push   $0xae
c0021e60:	e9 69 f8 ff ff       	jmp    c00216ce <intr_entry>

c0021e65 <intraf_stub>:
c0021e65:	55                   	push   %ebp
c0021e66:	6a 00                	push   $0x0
c0021e68:	68 af 00 00 00       	push   $0xaf
c0021e6d:	e9 5c f8 ff ff       	jmp    c00216ce <intr_entry>

c0021e72 <intrb0_stub>:

STUB(b0, zero) STUB(b1, zero) STUB(b2, zero) STUB(b3, zero)
c0021e72:	55                   	push   %ebp
c0021e73:	6a 00                	push   $0x0
c0021e75:	68 b0 00 00 00       	push   $0xb0
c0021e7a:	e9 4f f8 ff ff       	jmp    c00216ce <intr_entry>

c0021e7f <intrb1_stub>:
c0021e7f:	55                   	push   %ebp
c0021e80:	6a 00                	push   $0x0
c0021e82:	68 b1 00 00 00       	push   $0xb1
c0021e87:	e9 42 f8 ff ff       	jmp    c00216ce <intr_entry>

c0021e8c <intrb2_stub>:
c0021e8c:	55                   	push   %ebp
c0021e8d:	6a 00                	push   $0x0
c0021e8f:	68 b2 00 00 00       	push   $0xb2
c0021e94:	e9 35 f8 ff ff       	jmp    c00216ce <intr_entry>

c0021e99 <intrb3_stub>:
c0021e99:	55                   	push   %ebp
c0021e9a:	6a 00                	push   $0x0
c0021e9c:	68 b3 00 00 00       	push   $0xb3
c0021ea1:	e9 28 f8 ff ff       	jmp    c00216ce <intr_entry>

c0021ea6 <intrb4_stub>:
STUB(b4, zero) STUB(b5, zero) STUB(b6, zero) STUB(b7, zero)
c0021ea6:	55                   	push   %ebp
c0021ea7:	6a 00                	push   $0x0
c0021ea9:	68 b4 00 00 00       	push   $0xb4
c0021eae:	e9 1b f8 ff ff       	jmp    c00216ce <intr_entry>

c0021eb3 <intrb5_stub>:
c0021eb3:	55                   	push   %ebp
c0021eb4:	6a 00                	push   $0x0
c0021eb6:	68 b5 00 00 00       	push   $0xb5
c0021ebb:	e9 0e f8 ff ff       	jmp    c00216ce <intr_entry>

c0021ec0 <intrb6_stub>:
c0021ec0:	55                   	push   %ebp
c0021ec1:	6a 00                	push   $0x0
c0021ec3:	68 b6 00 00 00       	push   $0xb6
c0021ec8:	e9 01 f8 ff ff       	jmp    c00216ce <intr_entry>

c0021ecd <intrb7_stub>:
c0021ecd:	55                   	push   %ebp
c0021ece:	6a 00                	push   $0x0
c0021ed0:	68 b7 00 00 00       	push   $0xb7
c0021ed5:	e9 f4 f7 ff ff       	jmp    c00216ce <intr_entry>

c0021eda <intrb8_stub>:
STUB(b8, zero) STUB(b9, zero) STUB(ba, zero) STUB(bb, zero)
c0021eda:	55                   	push   %ebp
c0021edb:	6a 00                	push   $0x0
c0021edd:	68 b8 00 00 00       	push   $0xb8
c0021ee2:	e9 e7 f7 ff ff       	jmp    c00216ce <intr_entry>

c0021ee7 <intrb9_stub>:
c0021ee7:	55                   	push   %ebp
c0021ee8:	6a 00                	push   $0x0
c0021eea:	68 b9 00 00 00       	push   $0xb9
c0021eef:	e9 da f7 ff ff       	jmp    c00216ce <intr_entry>

c0021ef4 <intrba_stub>:
c0021ef4:	55                   	push   %ebp
c0021ef5:	6a 00                	push   $0x0
c0021ef7:	68 ba 00 00 00       	push   $0xba
c0021efc:	e9 cd f7 ff ff       	jmp    c00216ce <intr_entry>

c0021f01 <intrbb_stub>:
c0021f01:	55                   	push   %ebp
c0021f02:	6a 00                	push   $0x0
c0021f04:	68 bb 00 00 00       	push   $0xbb
c0021f09:	e9 c0 f7 ff ff       	jmp    c00216ce <intr_entry>

c0021f0e <intrbc_stub>:
STUB(bc, zero) STUB(bd, zero) STUB(be, zero) STUB(bf, zero)
c0021f0e:	55                   	push   %ebp
c0021f0f:	6a 00                	push   $0x0
c0021f11:	68 bc 00 00 00       	push   $0xbc
c0021f16:	e9 b3 f7 ff ff       	jmp    c00216ce <intr_entry>

c0021f1b <intrbd_stub>:
c0021f1b:	55                   	push   %ebp
c0021f1c:	6a 00                	push   $0x0
c0021f1e:	68 bd 00 00 00       	push   $0xbd
c0021f23:	e9 a6 f7 ff ff       	jmp    c00216ce <intr_entry>

c0021f28 <intrbe_stub>:
c0021f28:	55                   	push   %ebp
c0021f29:	6a 00                	push   $0x0
c0021f2b:	68 be 00 00 00       	push   $0xbe
c0021f30:	e9 99 f7 ff ff       	jmp    c00216ce <intr_entry>

c0021f35 <intrbf_stub>:
c0021f35:	55                   	push   %ebp
c0021f36:	6a 00                	push   $0x0
c0021f38:	68 bf 00 00 00       	push   $0xbf
c0021f3d:	e9 8c f7 ff ff       	jmp    c00216ce <intr_entry>

c0021f42 <intrc0_stub>:

STUB(c0, zero) STUB(c1, zero) STUB(c2, zero) STUB(c3, zero)
c0021f42:	55                   	push   %ebp
c0021f43:	6a 00                	push   $0x0
c0021f45:	68 c0 00 00 00       	push   $0xc0
c0021f4a:	e9 7f f7 ff ff       	jmp    c00216ce <intr_entry>

c0021f4f <intrc1_stub>:
c0021f4f:	55                   	push   %ebp
c0021f50:	6a 00                	push   $0x0
c0021f52:	68 c1 00 00 00       	push   $0xc1
c0021f57:	e9 72 f7 ff ff       	jmp    c00216ce <intr_entry>

c0021f5c <intrc2_stub>:
c0021f5c:	55                   	push   %ebp
c0021f5d:	6a 00                	push   $0x0
c0021f5f:	68 c2 00 00 00       	push   $0xc2
c0021f64:	e9 65 f7 ff ff       	jmp    c00216ce <intr_entry>

c0021f69 <intrc3_stub>:
c0021f69:	55                   	push   %ebp
c0021f6a:	6a 00                	push   $0x0
c0021f6c:	68 c3 00 00 00       	push   $0xc3
c0021f71:	e9 58 f7 ff ff       	jmp    c00216ce <intr_entry>

c0021f76 <intrc4_stub>:
STUB(c4, zero) STUB(c5, zero) STUB(c6, zero) STUB(c7, zero)
c0021f76:	55                   	push   %ebp
c0021f77:	6a 00                	push   $0x0
c0021f79:	68 c4 00 00 00       	push   $0xc4
c0021f7e:	e9 4b f7 ff ff       	jmp    c00216ce <intr_entry>

c0021f83 <intrc5_stub>:
c0021f83:	55                   	push   %ebp
c0021f84:	6a 00                	push   $0x0
c0021f86:	68 c5 00 00 00       	push   $0xc5
c0021f8b:	e9 3e f7 ff ff       	jmp    c00216ce <intr_entry>

c0021f90 <intrc6_stub>:
c0021f90:	55                   	push   %ebp
c0021f91:	6a 00                	push   $0x0
c0021f93:	68 c6 00 00 00       	push   $0xc6
c0021f98:	e9 31 f7 ff ff       	jmp    c00216ce <intr_entry>

c0021f9d <intrc7_stub>:
c0021f9d:	55                   	push   %ebp
c0021f9e:	6a 00                	push   $0x0
c0021fa0:	68 c7 00 00 00       	push   $0xc7
c0021fa5:	e9 24 f7 ff ff       	jmp    c00216ce <intr_entry>

c0021faa <intrc8_stub>:
STUB(c8, zero) STUB(c9, zero) STUB(ca, zero) STUB(cb, zero)
c0021faa:	55                   	push   %ebp
c0021fab:	6a 00                	push   $0x0
c0021fad:	68 c8 00 00 00       	push   $0xc8
c0021fb2:	e9 17 f7 ff ff       	jmp    c00216ce <intr_entry>

c0021fb7 <intrc9_stub>:
c0021fb7:	55                   	push   %ebp
c0021fb8:	6a 00                	push   $0x0
c0021fba:	68 c9 00 00 00       	push   $0xc9
c0021fbf:	e9 0a f7 ff ff       	jmp    c00216ce <intr_entry>

c0021fc4 <intrca_stub>:
c0021fc4:	55                   	push   %ebp
c0021fc5:	6a 00                	push   $0x0
c0021fc7:	68 ca 00 00 00       	push   $0xca
c0021fcc:	e9 fd f6 ff ff       	jmp    c00216ce <intr_entry>

c0021fd1 <intrcb_stub>:
c0021fd1:	55                   	push   %ebp
c0021fd2:	6a 00                	push   $0x0
c0021fd4:	68 cb 00 00 00       	push   $0xcb
c0021fd9:	e9 f0 f6 ff ff       	jmp    c00216ce <intr_entry>

c0021fde <intrcc_stub>:
STUB(cc, zero) STUB(cd, zero) STUB(ce, zero) STUB(cf, zero)
c0021fde:	55                   	push   %ebp
c0021fdf:	6a 00                	push   $0x0
c0021fe1:	68 cc 00 00 00       	push   $0xcc
c0021fe6:	e9 e3 f6 ff ff       	jmp    c00216ce <intr_entry>

c0021feb <intrcd_stub>:
c0021feb:	55                   	push   %ebp
c0021fec:	6a 00                	push   $0x0
c0021fee:	68 cd 00 00 00       	push   $0xcd
c0021ff3:	e9 d6 f6 ff ff       	jmp    c00216ce <intr_entry>

c0021ff8 <intrce_stub>:
c0021ff8:	55                   	push   %ebp
c0021ff9:	6a 00                	push   $0x0
c0021ffb:	68 ce 00 00 00       	push   $0xce
c0022000:	e9 c9 f6 ff ff       	jmp    c00216ce <intr_entry>

c0022005 <intrcf_stub>:
c0022005:	55                   	push   %ebp
c0022006:	6a 00                	push   $0x0
c0022008:	68 cf 00 00 00       	push   $0xcf
c002200d:	e9 bc f6 ff ff       	jmp    c00216ce <intr_entry>

c0022012 <intrd0_stub>:

STUB(d0, zero) STUB(d1, zero) STUB(d2, zero) STUB(d3, zero)
c0022012:	55                   	push   %ebp
c0022013:	6a 00                	push   $0x0
c0022015:	68 d0 00 00 00       	push   $0xd0
c002201a:	e9 af f6 ff ff       	jmp    c00216ce <intr_entry>

c002201f <intrd1_stub>:
c002201f:	55                   	push   %ebp
c0022020:	6a 00                	push   $0x0
c0022022:	68 d1 00 00 00       	push   $0xd1
c0022027:	e9 a2 f6 ff ff       	jmp    c00216ce <intr_entry>

c002202c <intrd2_stub>:
c002202c:	55                   	push   %ebp
c002202d:	6a 00                	push   $0x0
c002202f:	68 d2 00 00 00       	push   $0xd2
c0022034:	e9 95 f6 ff ff       	jmp    c00216ce <intr_entry>

c0022039 <intrd3_stub>:
c0022039:	55                   	push   %ebp
c002203a:	6a 00                	push   $0x0
c002203c:	68 d3 00 00 00       	push   $0xd3
c0022041:	e9 88 f6 ff ff       	jmp    c00216ce <intr_entry>

c0022046 <intrd4_stub>:
STUB(d4, zero) STUB(d5, zero) STUB(d6, zero) STUB(d7, zero)
c0022046:	55                   	push   %ebp
c0022047:	6a 00                	push   $0x0
c0022049:	68 d4 00 00 00       	push   $0xd4
c002204e:	e9 7b f6 ff ff       	jmp    c00216ce <intr_entry>

c0022053 <intrd5_stub>:
c0022053:	55                   	push   %ebp
c0022054:	6a 00                	push   $0x0
c0022056:	68 d5 00 00 00       	push   $0xd5
c002205b:	e9 6e f6 ff ff       	jmp    c00216ce <intr_entry>

c0022060 <intrd6_stub>:
c0022060:	55                   	push   %ebp
c0022061:	6a 00                	push   $0x0
c0022063:	68 d6 00 00 00       	push   $0xd6
c0022068:	e9 61 f6 ff ff       	jmp    c00216ce <intr_entry>

c002206d <intrd7_stub>:
c002206d:	55                   	push   %ebp
c002206e:	6a 00                	push   $0x0
c0022070:	68 d7 00 00 00       	push   $0xd7
c0022075:	e9 54 f6 ff ff       	jmp    c00216ce <intr_entry>

c002207a <intrd8_stub>:
STUB(d8, zero) STUB(d9, zero) STUB(da, zero) STUB(db, zero)
c002207a:	55                   	push   %ebp
c002207b:	6a 00                	push   $0x0
c002207d:	68 d8 00 00 00       	push   $0xd8
c0022082:	e9 47 f6 ff ff       	jmp    c00216ce <intr_entry>

c0022087 <intrd9_stub>:
c0022087:	55                   	push   %ebp
c0022088:	6a 00                	push   $0x0
c002208a:	68 d9 00 00 00       	push   $0xd9
c002208f:	e9 3a f6 ff ff       	jmp    c00216ce <intr_entry>

c0022094 <intrda_stub>:
c0022094:	55                   	push   %ebp
c0022095:	6a 00                	push   $0x0
c0022097:	68 da 00 00 00       	push   $0xda
c002209c:	e9 2d f6 ff ff       	jmp    c00216ce <intr_entry>

c00220a1 <intrdb_stub>:
c00220a1:	55                   	push   %ebp
c00220a2:	6a 00                	push   $0x0
c00220a4:	68 db 00 00 00       	push   $0xdb
c00220a9:	e9 20 f6 ff ff       	jmp    c00216ce <intr_entry>

c00220ae <intrdc_stub>:
STUB(dc, zero) STUB(dd, zero) STUB(de, zero) STUB(df, zero)
c00220ae:	55                   	push   %ebp
c00220af:	6a 00                	push   $0x0
c00220b1:	68 dc 00 00 00       	push   $0xdc
c00220b6:	e9 13 f6 ff ff       	jmp    c00216ce <intr_entry>

c00220bb <intrdd_stub>:
c00220bb:	55                   	push   %ebp
c00220bc:	6a 00                	push   $0x0
c00220be:	68 dd 00 00 00       	push   $0xdd
c00220c3:	e9 06 f6 ff ff       	jmp    c00216ce <intr_entry>

c00220c8 <intrde_stub>:
c00220c8:	55                   	push   %ebp
c00220c9:	6a 00                	push   $0x0
c00220cb:	68 de 00 00 00       	push   $0xde
c00220d0:	e9 f9 f5 ff ff       	jmp    c00216ce <intr_entry>

c00220d5 <intrdf_stub>:
c00220d5:	55                   	push   %ebp
c00220d6:	6a 00                	push   $0x0
c00220d8:	68 df 00 00 00       	push   $0xdf
c00220dd:	e9 ec f5 ff ff       	jmp    c00216ce <intr_entry>

c00220e2 <intre0_stub>:

STUB(e0, zero) STUB(e1, zero) STUB(e2, zero) STUB(e3, zero)
c00220e2:	55                   	push   %ebp
c00220e3:	6a 00                	push   $0x0
c00220e5:	68 e0 00 00 00       	push   $0xe0
c00220ea:	e9 df f5 ff ff       	jmp    c00216ce <intr_entry>

c00220ef <intre1_stub>:
c00220ef:	55                   	push   %ebp
c00220f0:	6a 00                	push   $0x0
c00220f2:	68 e1 00 00 00       	push   $0xe1
c00220f7:	e9 d2 f5 ff ff       	jmp    c00216ce <intr_entry>

c00220fc <intre2_stub>:
c00220fc:	55                   	push   %ebp
c00220fd:	6a 00                	push   $0x0
c00220ff:	68 e2 00 00 00       	push   $0xe2
c0022104:	e9 c5 f5 ff ff       	jmp    c00216ce <intr_entry>

c0022109 <intre3_stub>:
c0022109:	55                   	push   %ebp
c002210a:	6a 00                	push   $0x0
c002210c:	68 e3 00 00 00       	push   $0xe3
c0022111:	e9 b8 f5 ff ff       	jmp    c00216ce <intr_entry>

c0022116 <intre4_stub>:
STUB(e4, zero) STUB(e5, zero) STUB(e6, zero) STUB(e7, zero)
c0022116:	55                   	push   %ebp
c0022117:	6a 00                	push   $0x0
c0022119:	68 e4 00 00 00       	push   $0xe4
c002211e:	e9 ab f5 ff ff       	jmp    c00216ce <intr_entry>

c0022123 <intre5_stub>:
c0022123:	55                   	push   %ebp
c0022124:	6a 00                	push   $0x0
c0022126:	68 e5 00 00 00       	push   $0xe5
c002212b:	e9 9e f5 ff ff       	jmp    c00216ce <intr_entry>

c0022130 <intre6_stub>:
c0022130:	55                   	push   %ebp
c0022131:	6a 00                	push   $0x0
c0022133:	68 e6 00 00 00       	push   $0xe6
c0022138:	e9 91 f5 ff ff       	jmp    c00216ce <intr_entry>

c002213d <intre7_stub>:
c002213d:	55                   	push   %ebp
c002213e:	6a 00                	push   $0x0
c0022140:	68 e7 00 00 00       	push   $0xe7
c0022145:	e9 84 f5 ff ff       	jmp    c00216ce <intr_entry>

c002214a <intre8_stub>:
STUB(e8, zero) STUB(e9, zero) STUB(ea, zero) STUB(eb, zero)
c002214a:	55                   	push   %ebp
c002214b:	6a 00                	push   $0x0
c002214d:	68 e8 00 00 00       	push   $0xe8
c0022152:	e9 77 f5 ff ff       	jmp    c00216ce <intr_entry>

c0022157 <intre9_stub>:
c0022157:	55                   	push   %ebp
c0022158:	6a 00                	push   $0x0
c002215a:	68 e9 00 00 00       	push   $0xe9
c002215f:	e9 6a f5 ff ff       	jmp    c00216ce <intr_entry>

c0022164 <intrea_stub>:
c0022164:	55                   	push   %ebp
c0022165:	6a 00                	push   $0x0
c0022167:	68 ea 00 00 00       	push   $0xea
c002216c:	e9 5d f5 ff ff       	jmp    c00216ce <intr_entry>

c0022171 <intreb_stub>:
c0022171:	55                   	push   %ebp
c0022172:	6a 00                	push   $0x0
c0022174:	68 eb 00 00 00       	push   $0xeb
c0022179:	e9 50 f5 ff ff       	jmp    c00216ce <intr_entry>

c002217e <intrec_stub>:
STUB(ec, zero) STUB(ed, zero) STUB(ee, zero) STUB(ef, zero)
c002217e:	55                   	push   %ebp
c002217f:	6a 00                	push   $0x0
c0022181:	68 ec 00 00 00       	push   $0xec
c0022186:	e9 43 f5 ff ff       	jmp    c00216ce <intr_entry>

c002218b <intred_stub>:
c002218b:	55                   	push   %ebp
c002218c:	6a 00                	push   $0x0
c002218e:	68 ed 00 00 00       	push   $0xed
c0022193:	e9 36 f5 ff ff       	jmp    c00216ce <intr_entry>

c0022198 <intree_stub>:
c0022198:	55                   	push   %ebp
c0022199:	6a 00                	push   $0x0
c002219b:	68 ee 00 00 00       	push   $0xee
c00221a0:	e9 29 f5 ff ff       	jmp    c00216ce <intr_entry>

c00221a5 <intref_stub>:
c00221a5:	55                   	push   %ebp
c00221a6:	6a 00                	push   $0x0
c00221a8:	68 ef 00 00 00       	push   $0xef
c00221ad:	e9 1c f5 ff ff       	jmp    c00216ce <intr_entry>

c00221b2 <intrf0_stub>:

STUB(f0, zero) STUB(f1, zero) STUB(f2, zero) STUB(f3, zero)
c00221b2:	55                   	push   %ebp
c00221b3:	6a 00                	push   $0x0
c00221b5:	68 f0 00 00 00       	push   $0xf0
c00221ba:	e9 0f f5 ff ff       	jmp    c00216ce <intr_entry>

c00221bf <intrf1_stub>:
c00221bf:	55                   	push   %ebp
c00221c0:	6a 00                	push   $0x0
c00221c2:	68 f1 00 00 00       	push   $0xf1
c00221c7:	e9 02 f5 ff ff       	jmp    c00216ce <intr_entry>

c00221cc <intrf2_stub>:
c00221cc:	55                   	push   %ebp
c00221cd:	6a 00                	push   $0x0
c00221cf:	68 f2 00 00 00       	push   $0xf2
c00221d4:	e9 f5 f4 ff ff       	jmp    c00216ce <intr_entry>

c00221d9 <intrf3_stub>:
c00221d9:	55                   	push   %ebp
c00221da:	6a 00                	push   $0x0
c00221dc:	68 f3 00 00 00       	push   $0xf3
c00221e1:	e9 e8 f4 ff ff       	jmp    c00216ce <intr_entry>

c00221e6 <intrf4_stub>:
STUB(f4, zero) STUB(f5, zero) STUB(f6, zero) STUB(f7, zero)
c00221e6:	55                   	push   %ebp
c00221e7:	6a 00                	push   $0x0
c00221e9:	68 f4 00 00 00       	push   $0xf4
c00221ee:	e9 db f4 ff ff       	jmp    c00216ce <intr_entry>

c00221f3 <intrf5_stub>:
c00221f3:	55                   	push   %ebp
c00221f4:	6a 00                	push   $0x0
c00221f6:	68 f5 00 00 00       	push   $0xf5
c00221fb:	e9 ce f4 ff ff       	jmp    c00216ce <intr_entry>

c0022200 <intrf6_stub>:
c0022200:	55                   	push   %ebp
c0022201:	6a 00                	push   $0x0
c0022203:	68 f6 00 00 00       	push   $0xf6
c0022208:	e9 c1 f4 ff ff       	jmp    c00216ce <intr_entry>

c002220d <intrf7_stub>:
c002220d:	55                   	push   %ebp
c002220e:	6a 00                	push   $0x0
c0022210:	68 f7 00 00 00       	push   $0xf7
c0022215:	e9 b4 f4 ff ff       	jmp    c00216ce <intr_entry>

c002221a <intrf8_stub>:
STUB(f8, zero) STUB(f9, zero) STUB(fa, zero) STUB(fb, zero)
c002221a:	55                   	push   %ebp
c002221b:	6a 00                	push   $0x0
c002221d:	68 f8 00 00 00       	push   $0xf8
c0022222:	e9 a7 f4 ff ff       	jmp    c00216ce <intr_entry>

c0022227 <intrf9_stub>:
c0022227:	55                   	push   %ebp
c0022228:	6a 00                	push   $0x0
c002222a:	68 f9 00 00 00       	push   $0xf9
c002222f:	e9 9a f4 ff ff       	jmp    c00216ce <intr_entry>

c0022234 <intrfa_stub>:
c0022234:	55                   	push   %ebp
c0022235:	6a 00                	push   $0x0
c0022237:	68 fa 00 00 00       	push   $0xfa
c002223c:	e9 8d f4 ff ff       	jmp    c00216ce <intr_entry>

c0022241 <intrfb_stub>:
c0022241:	55                   	push   %ebp
c0022242:	6a 00                	push   $0x0
c0022244:	68 fb 00 00 00       	push   $0xfb
c0022249:	e9 80 f4 ff ff       	jmp    c00216ce <intr_entry>

c002224e <intrfc_stub>:
STUB(fc, zero) STUB(fd, zero) STUB(fe, zero) STUB(ff, zero)
c002224e:	55                   	push   %ebp
c002224f:	6a 00                	push   $0x0
c0022251:	68 fc 00 00 00       	push   $0xfc
c0022256:	e9 73 f4 ff ff       	jmp    c00216ce <intr_entry>

c002225b <intrfd_stub>:
c002225b:	55                   	push   %ebp
c002225c:	6a 00                	push   $0x0
c002225e:	68 fd 00 00 00       	push   $0xfd
c0022263:	e9 66 f4 ff ff       	jmp    c00216ce <intr_entry>

c0022268 <intrfe_stub>:
c0022268:	55                   	push   %ebp
c0022269:	6a 00                	push   $0x0
c002226b:	68 fe 00 00 00       	push   $0xfe
c0022270:	e9 59 f4 ff ff       	jmp    c00216ce <intr_entry>

c0022275 <intrff_stub>:
c0022275:	55                   	push   %ebp
c0022276:	6a 00                	push   $0x0
c0022278:	68 ff 00 00 00       	push   $0xff
c002227d:	e9 4c f4 ff ff       	jmp    c00216ce <intr_entry>

c0022282 <sema_init>:

   - up or "V": increment the value (and wake up one waiting
     thread, if any). */
void
sema_init (struct semaphore *sema, unsigned value) 
{
c0022282:	83 ec 0c             	sub    $0xc,%esp
c0022285:	8b 44 24 10          	mov    0x10(%esp),%eax
  ASSERT (sema != NULL);
c0022289:	85 c0                	test   %eax,%eax
c002228b:	74 16                	je     c00222a3 <sema_init+0x21>

  sema->value = value;
c002228d:	8b 54 24 14          	mov    0x14(%esp),%edx
c0022291:	89 10                	mov    %edx,(%eax)
  list_init (&sema->waiters);
c0022293:	83 ec 0c             	sub    $0xc,%esp
c0022296:	83 c0 04             	add    $0x4,%eax
c0022299:	50                   	push   %eax
c002229a:	e8 17 56 00 00       	call   c00278b6 <list_init>
}
c002229f:	83 c4 1c             	add    $0x1c,%esp
c00222a2:	c3                   	ret    
  ASSERT (sema != NULL);
c00222a3:	83 ec 0c             	sub    $0xc,%esp
c00222a6:	68 16 d6 02 c0       	push   $0xc002d616
c00222ab:	68 9f cd 02 c0       	push   $0xc002cd9f
c00222b0:	68 c8 b8 02 c0       	push   $0xc002b8c8
c00222b5:	6a 2f                	push   $0x2f
c00222b7:	68 23 d6 02 c0       	push   $0xc002d623
c00222bc:	e8 4e 55 00 00       	call   c002780f <debug_panic>

c00222c1 <sema_down>:
   interrupt handler.  This function may be called with
   interrupts disabled, but if it sleeps then the next scheduled
   thread will probably turn interrupts back on. */
void
sema_down (struct semaphore *sema) 
{
c00222c1:	57                   	push   %edi
c00222c2:	56                   	push   %esi
c00222c3:	53                   	push   %ebx
c00222c4:	8b 5c 24 10          	mov    0x10(%esp),%ebx
  enum intr_level old_level;

  ASSERT (sema != NULL);
c00222c8:	85 db                	test   %ebx,%ebx
c00222ca:	74 4c                	je     c0022318 <sema_down+0x57>
  ASSERT (!intr_context ());
c00222cc:	e8 a4 f1 ff ff       	call   c0021475 <intr_context>
c00222d1:	84 c0                	test   %al,%al
c00222d3:	75 61                	jne    c0022336 <sema_down+0x75>

  old_level = intr_disable ();
c00222d5:	e8 7a ef ff ff       	call   c0021254 <intr_disable>
c00222da:	89 c7                	mov    %eax,%edi
  while (sema->value == 0) 
c00222dc:	8b 03                	mov    (%ebx),%eax
c00222de:	85 c0                	test   %eax,%eax
c00222e0:	75 23                	jne    c0022305 <sema_down+0x44>
    {
      list_push_back (&sema->waiters, &thread_current ()->elem);
c00222e2:	8d 73 04             	lea    0x4(%ebx),%esi
c00222e5:	e8 65 e8 ff ff       	call   c0020b4f <thread_current>
c00222ea:	83 ec 08             	sub    $0x8,%esp
c00222ed:	83 c0 38             	add    $0x38,%eax
c00222f0:	50                   	push   %eax
c00222f1:	56                   	push   %esi
c00222f2:	e8 5c 5a 00 00       	call   c0027d53 <list_push_back>
      thread_block ();
c00222f7:	e8 c5 eb ff ff       	call   c0020ec1 <thread_block>
  while (sema->value == 0) 
c00222fc:	8b 03                	mov    (%ebx),%eax
c00222fe:	83 c4 10             	add    $0x10,%esp
c0022301:	85 c0                	test   %eax,%eax
c0022303:	74 e0                	je     c00222e5 <sema_down+0x24>
    }
  sema->value--;
c0022305:	48                   	dec    %eax
c0022306:	89 03                	mov    %eax,(%ebx)
  intr_set_level (old_level);
c0022308:	83 ec 0c             	sub    $0xc,%esp
c002230b:	57                   	push   %edi
c002230c:	e8 4a ef ff ff       	call   c002125b <intr_set_level>
}
c0022311:	83 c4 10             	add    $0x10,%esp
c0022314:	5b                   	pop    %ebx
c0022315:	5e                   	pop    %esi
c0022316:	5f                   	pop    %edi
c0022317:	c3                   	ret    
  ASSERT (sema != NULL);
c0022318:	83 ec 0c             	sub    $0xc,%esp
c002231b:	68 16 d6 02 c0       	push   $0xc002d616
c0022320:	68 9f cd 02 c0       	push   $0xc002cd9f
c0022325:	68 bc b8 02 c0       	push   $0xc002b8bc
c002232a:	6a 41                	push   $0x41
c002232c:	68 23 d6 02 c0       	push   $0xc002d623
c0022331:	e8 d9 54 00 00       	call   c002780f <debug_panic>
  ASSERT (!intr_context ());
c0022336:	83 ec 0c             	sub    $0xc,%esp
c0022339:	68 cc d1 02 c0       	push   $0xc002d1cc
c002233e:	68 9f cd 02 c0       	push   $0xc002cd9f
c0022343:	68 bc b8 02 c0       	push   $0xc002b8bc
c0022348:	6a 42                	push   $0x42
c002234a:	68 23 d6 02 c0       	push   $0xc002d623
c002234f:	e8 bb 54 00 00       	call   c002780f <debug_panic>

c0022354 <sema_try_down>:
   decremented, false otherwise.

   This function may be called from an interrupt handler. */
bool
sema_try_down (struct semaphore *sema) 
{
c0022354:	53                   	push   %ebx
c0022355:	83 ec 08             	sub    $0x8,%esp
c0022358:	8b 5c 24 10          	mov    0x10(%esp),%ebx
  enum intr_level old_level;
  bool success;

  ASSERT (sema != NULL);
c002235c:	85 db                	test   %ebx,%ebx
c002235e:	74 20                	je     c0022380 <sema_try_down+0x2c>

  old_level = intr_disable ();
c0022360:	e8 ef ee ff ff       	call   c0021254 <intr_disable>
  if (sema->value > 0) 
c0022365:	8b 13                	mov    (%ebx),%edx
c0022367:	85 d2                	test   %edx,%edx
c0022369:	74 33                	je     c002239e <sema_try_down+0x4a>
    {
      sema->value--;
c002236b:	4a                   	dec    %edx
c002236c:	89 13                	mov    %edx,(%ebx)
      success = true; 
c002236e:	b3 01                	mov    $0x1,%bl
    }
  else
    success = false;
  intr_set_level (old_level);
c0022370:	83 ec 0c             	sub    $0xc,%esp
c0022373:	50                   	push   %eax
c0022374:	e8 e2 ee ff ff       	call   c002125b <intr_set_level>

  return success;
}
c0022379:	88 d8                	mov    %bl,%al
c002237b:	83 c4 18             	add    $0x18,%esp
c002237e:	5b                   	pop    %ebx
c002237f:	c3                   	ret    
  ASSERT (sema != NULL);
c0022380:	83 ec 0c             	sub    $0xc,%esp
c0022383:	68 16 d6 02 c0       	push   $0xc002d616
c0022388:	68 9f cd 02 c0       	push   $0xc002cd9f
c002238d:	68 ac b8 02 c0       	push   $0xc002b8ac
c0022392:	6a 59                	push   $0x59
c0022394:	68 23 d6 02 c0       	push   $0xc002d623
c0022399:	e8 71 54 00 00       	call   c002780f <debug_panic>
    success = false;
c002239e:	b3 00                	mov    $0x0,%bl
c00223a0:	eb ce                	jmp    c0022370 <sema_try_down+0x1c>

c00223a2 <sema_up>:
   and wakes up one thread of those waiting for SEMA, if any.

   This function may be called from an interrupt handler. */
void
sema_up (struct semaphore *sema) 
{
c00223a2:	57                   	push   %edi
c00223a3:	56                   	push   %esi
c00223a4:	53                   	push   %ebx
c00223a5:	8b 5c 24 10          	mov    0x10(%esp),%ebx
  enum intr_level old_level;

  ASSERT (sema != NULL);
c00223a9:	85 db                	test   %ebx,%ebx
c00223ab:	74 2c                	je     c00223d9 <sema_up+0x37>

  old_level = intr_disable ();
c00223ad:	e8 a2 ee ff ff       	call   c0021254 <intr_disable>
c00223b2:	89 c7                	mov    %eax,%edi
  if (!list_empty (&sema->waiters)) 
c00223b4:	8d 73 04             	lea    0x4(%ebx),%esi
c00223b7:	83 ec 0c             	sub    $0xc,%esp
c00223ba:	56                   	push   %esi
c00223bb:	e8 3b 5a 00 00       	call   c0027dfb <list_empty>
c00223c0:	83 c4 10             	add    $0x10,%esp
c00223c3:	84 c0                	test   %al,%al
c00223c5:	74 30                	je     c00223f7 <sema_up+0x55>
    thread_unblock (list_entry (list_pop_front (&sema->waiters),
                                struct thread, elem));
  sema->value++;
c00223c7:	ff 03                	incl   (%ebx)
  intr_set_level (old_level);
c00223c9:	83 ec 0c             	sub    $0xc,%esp
c00223cc:	57                   	push   %edi
c00223cd:	e8 89 ee ff ff       	call   c002125b <intr_set_level>
}
c00223d2:	83 c4 10             	add    $0x10,%esp
c00223d5:	5b                   	pop    %ebx
c00223d6:	5e                   	pop    %esi
c00223d7:	5f                   	pop    %edi
c00223d8:	c3                   	ret    
  ASSERT (sema != NULL);
c00223d9:	83 ec 0c             	sub    $0xc,%esp
c00223dc:	68 16 d6 02 c0       	push   $0xc002d616
c00223e1:	68 9f cd 02 c0       	push   $0xc002cd9f
c00223e6:	68 a4 b8 02 c0       	push   $0xc002b8a4
c00223eb:	6a 71                	push   $0x71
c00223ed:	68 23 d6 02 c0       	push   $0xc002d623
c00223f2:	e8 18 54 00 00       	call   c002780f <debug_panic>
    thread_unblock (list_entry (list_pop_front (&sema->waiters),
c00223f7:	83 ec 0c             	sub    $0xc,%esp
c00223fa:	56                   	push   %esi
c00223fb:	e8 5d 5a 00 00       	call   c0027e5d <list_pop_front>
c0022400:	83 e8 38             	sub    $0x38,%eax
c0022403:	89 04 24             	mov    %eax,(%esp)
c0022406:	e8 a1 e5 ff ff       	call   c00209ac <thread_unblock>
c002240b:	83 c4 10             	add    $0x10,%esp
c002240e:	eb b7                	jmp    c00223c7 <sema_up+0x25>

c0022410 <sema_test_helper>:
}

/* Thread function used by sema_self_test(). */
static void
sema_test_helper (void *sema_) 
{
c0022410:	57                   	push   %edi
c0022411:	56                   	push   %esi
c0022412:	53                   	push   %ebx
c0022413:	8b 74 24 10          	mov    0x10(%esp),%esi
c0022417:	bb 0a 00 00 00       	mov    $0xa,%ebx
  int i;

  for (i = 0; i < 10; i++) 
    {
      sema_down (&sema[0]);
      sema_up (&sema[1]);
c002241c:	8d 7e 14             	lea    0x14(%esi),%edi
      sema_down (&sema[0]);
c002241f:	83 ec 0c             	sub    $0xc,%esp
c0022422:	56                   	push   %esi
c0022423:	e8 99 fe ff ff       	call   c00222c1 <sema_down>
      sema_up (&sema[1]);
c0022428:	89 3c 24             	mov    %edi,(%esp)
c002242b:	e8 72 ff ff ff       	call   c00223a2 <sema_up>
  for (i = 0; i < 10; i++) 
c0022430:	83 c4 10             	add    $0x10,%esp
c0022433:	4b                   	dec    %ebx
c0022434:	75 e9                	jne    c002241f <sema_test_helper+0xf>
    }
}
c0022436:	5b                   	pop    %ebx
c0022437:	5e                   	pop    %esi
c0022438:	5f                   	pop    %edi
c0022439:	c3                   	ret    

c002243a <sema_self_test>:
{
c002243a:	57                   	push   %edi
c002243b:	56                   	push   %esi
c002243c:	53                   	push   %ebx
c002243d:	83 ec 3c             	sub    $0x3c,%esp
  printf ("Testing semaphores...");
c0022440:	68 39 d6 02 c0       	push   $0xc002d639
c0022445:	e8 17 39 00 00       	call   c0025d61 <printf>
  sema_init (&sema[0], 0);
c002244a:	83 c4 08             	add    $0x8,%esp
c002244d:	6a 00                	push   $0x0
c002244f:	8d 5c 24 14          	lea    0x14(%esp),%ebx
c0022453:	53                   	push   %ebx
c0022454:	e8 29 fe ff ff       	call   c0022282 <sema_init>
  sema_init (&sema[1], 0);
c0022459:	83 c4 08             	add    $0x8,%esp
c002245c:	6a 00                	push   $0x0
c002245e:	8d 44 24 28          	lea    0x28(%esp),%eax
c0022462:	50                   	push   %eax
c0022463:	e8 1a fe ff ff       	call   c0022282 <sema_init>
  thread_create ("sema-test", PRI_DEFAULT, sema_test_helper, &sema);
c0022468:	53                   	push   %ebx
c0022469:	68 10 24 02 c0       	push   $0xc0022410
c002246e:	6a 1f                	push   $0x1f
c0022470:	68 4f d6 02 c0       	push   $0xc002d64f
c0022475:	e8 c0 e5 ff ff       	call   c0020a3a <thread_create>
c002247a:	83 c4 20             	add    $0x20,%esp
c002247d:	bb 0a 00 00 00       	mov    $0xa,%ebx
      sema_up (&sema[0]);
c0022482:	8d 7c 24 08          	lea    0x8(%esp),%edi
      sema_down (&sema[1]);
c0022486:	8d 74 24 1c          	lea    0x1c(%esp),%esi
      sema_up (&sema[0]);
c002248a:	83 ec 0c             	sub    $0xc,%esp
c002248d:	57                   	push   %edi
c002248e:	e8 0f ff ff ff       	call   c00223a2 <sema_up>
      sema_down (&sema[1]);
c0022493:	89 34 24             	mov    %esi,(%esp)
c0022496:	e8 26 fe ff ff       	call   c00222c1 <sema_down>
  for (i = 0; i < 10; i++) 
c002249b:	83 c4 10             	add    $0x10,%esp
c002249e:	4b                   	dec    %ebx
c002249f:	75 e9                	jne    c002248a <sema_self_test+0x50>
  printf ("done.\n");
c00224a1:	83 ec 0c             	sub    $0xc,%esp
c00224a4:	68 59 d6 02 c0       	push   $0xc002d659
c00224a9:	e8 af 6d 00 00       	call   c002925d <puts>
}
c00224ae:	83 c4 40             	add    $0x40,%esp
c00224b1:	5b                   	pop    %ebx
c00224b2:	5e                   	pop    %esi
c00224b3:	5f                   	pop    %edi
c00224b4:	c3                   	ret    

c00224b5 <lock_init>:
   acquire and release it.  When these restrictions prove
   onerous, it's a good sign that a semaphore should be used,
   instead of a lock. */
void
lock_init (struct lock *lock)
{
c00224b5:	83 ec 0c             	sub    $0xc,%esp
c00224b8:	8b 44 24 10          	mov    0x10(%esp),%eax
  ASSERT (lock != NULL);
c00224bc:	85 c0                	test   %eax,%eax
c00224be:	74 18                	je     c00224d8 <lock_init+0x23>

  lock->holder = NULL;
c00224c0:	c7 00 00 00 00 00    	movl   $0x0,(%eax)
  sema_init (&lock->semaphore, 1);
c00224c6:	83 ec 08             	sub    $0x8,%esp
c00224c9:	6a 01                	push   $0x1
c00224cb:	83 c0 04             	add    $0x4,%eax
c00224ce:	50                   	push   %eax
c00224cf:	e8 ae fd ff ff       	call   c0022282 <sema_init>
}
c00224d4:	83 c4 1c             	add    $0x1c,%esp
c00224d7:	c3                   	ret    
  ASSERT (lock != NULL);
c00224d8:	83 ec 0c             	sub    $0xc,%esp
c00224db:	68 5f d6 02 c0       	push   $0xc002d65f
c00224e0:	68 9f cd 02 c0       	push   $0xc002cd9f
c00224e5:	68 98 b8 02 c0       	push   $0xc002b898
c00224ea:	68 b2 00 00 00       	push   $0xb2
c00224ef:	68 23 d6 02 c0       	push   $0xc002d623
c00224f4:	e8 16 53 00 00       	call   c002780f <debug_panic>

c00224f9 <lock_held_by_current_thread>:
/* Returns true if the current thread holds LOCK, false
   otherwise.  (Note that testing whether some other thread holds
   a lock would be racy.) */
bool
lock_held_by_current_thread (const struct lock *lock) 
{
c00224f9:	53                   	push   %ebx
c00224fa:	83 ec 08             	sub    $0x8,%esp
c00224fd:	8b 44 24 10          	mov    0x10(%esp),%eax
  ASSERT (lock != NULL);
c0022501:	85 c0                	test   %eax,%eax
c0022503:	74 11                	je     c0022516 <lock_held_by_current_thread+0x1d>

  return lock->holder == thread_current ();
c0022505:	8b 18                	mov    (%eax),%ebx
c0022507:	e8 43 e6 ff ff       	call   c0020b4f <thread_current>
c002250c:	39 c3                	cmp    %eax,%ebx
c002250e:	0f 94 c0             	sete   %al
}
c0022511:	83 c4 08             	add    $0x8,%esp
c0022514:	5b                   	pop    %ebx
c0022515:	c3                   	ret    
  ASSERT (lock != NULL);
c0022516:	83 ec 0c             	sub    $0xc,%esp
c0022519:	68 5f d6 02 c0       	push   $0xc002d65f
c002251e:	68 9f cd 02 c0       	push   $0xc002cd9f
c0022523:	68 48 b8 02 c0       	push   $0xc002b848
c0022528:	68 f4 00 00 00       	push   $0xf4
c002252d:	68 23 d6 02 c0       	push   $0xc002d623
c0022532:	e8 d8 52 00 00       	call   c002780f <debug_panic>

c0022537 <lock_acquire>:
{
c0022537:	53                   	push   %ebx
c0022538:	83 ec 08             	sub    $0x8,%esp
c002253b:	8b 5c 24 10          	mov    0x10(%esp),%ebx
  ASSERT (lock != NULL);
c002253f:	85 db                	test   %ebx,%ebx
c0022541:	74 31                	je     c0022574 <lock_acquire+0x3d>
  ASSERT (!intr_context ());
c0022543:	e8 2d ef ff ff       	call   c0021475 <intr_context>
c0022548:	84 c0                	test   %al,%al
c002254a:	75 49                	jne    c0022595 <lock_acquire+0x5e>
  ASSERT (!lock_held_by_current_thread (lock));
c002254c:	83 ec 0c             	sub    $0xc,%esp
c002254f:	53                   	push   %ebx
c0022550:	e8 a4 ff ff ff       	call   c00224f9 <lock_held_by_current_thread>
c0022555:	83 c4 10             	add    $0x10,%esp
c0022558:	84 c0                	test   %al,%al
c002255a:	75 5a                	jne    c00225b6 <lock_acquire+0x7f>
  sema_down (&lock->semaphore);
c002255c:	83 ec 0c             	sub    $0xc,%esp
c002255f:	8d 43 04             	lea    0x4(%ebx),%eax
c0022562:	50                   	push   %eax
c0022563:	e8 59 fd ff ff       	call   c00222c1 <sema_down>
  lock->holder = thread_current ();
c0022568:	e8 e2 e5 ff ff       	call   c0020b4f <thread_current>
c002256d:	89 03                	mov    %eax,(%ebx)
}
c002256f:	83 c4 18             	add    $0x18,%esp
c0022572:	5b                   	pop    %ebx
c0022573:	c3                   	ret    
  ASSERT (lock != NULL);
c0022574:	83 ec 0c             	sub    $0xc,%esp
c0022577:	68 5f d6 02 c0       	push   $0xc002d65f
c002257c:	68 9f cd 02 c0       	push   $0xc002cd9f
c0022581:	68 88 b8 02 c0       	push   $0xc002b888
c0022586:	68 c3 00 00 00       	push   $0xc3
c002258b:	68 23 d6 02 c0       	push   $0xc002d623
c0022590:	e8 7a 52 00 00       	call   c002780f <debug_panic>
  ASSERT (!intr_context ());
c0022595:	83 ec 0c             	sub    $0xc,%esp
c0022598:	68 cc d1 02 c0       	push   $0xc002d1cc
c002259d:	68 9f cd 02 c0       	push   $0xc002cd9f
c00225a2:	68 88 b8 02 c0       	push   $0xc002b888
c00225a7:	68 c4 00 00 00       	push   $0xc4
c00225ac:	68 23 d6 02 c0       	push   $0xc002d623
c00225b1:	e8 59 52 00 00       	call   c002780f <debug_panic>
  ASSERT (!lock_held_by_current_thread (lock));
c00225b6:	83 ec 0c             	sub    $0xc,%esp
c00225b9:	68 7c d6 02 c0       	push   $0xc002d67c
c00225be:	68 9f cd 02 c0       	push   $0xc002cd9f
c00225c3:	68 88 b8 02 c0       	push   $0xc002b888
c00225c8:	68 c5 00 00 00       	push   $0xc5
c00225cd:	68 23 d6 02 c0       	push   $0xc002d623
c00225d2:	e8 38 52 00 00       	call   c002780f <debug_panic>

c00225d7 <lock_try_acquire>:
{
c00225d7:	56                   	push   %esi
c00225d8:	53                   	push   %ebx
c00225d9:	83 ec 04             	sub    $0x4,%esp
c00225dc:	8b 5c 24 10          	mov    0x10(%esp),%ebx
  ASSERT (lock != NULL);
c00225e0:	85 db                	test   %ebx,%ebx
c00225e2:	74 2d                	je     c0022611 <lock_try_acquire+0x3a>
  ASSERT (!lock_held_by_current_thread (lock));
c00225e4:	83 ec 0c             	sub    $0xc,%esp
c00225e7:	53                   	push   %ebx
c00225e8:	e8 0c ff ff ff       	call   c00224f9 <lock_held_by_current_thread>
c00225ed:	83 c4 10             	add    $0x10,%esp
c00225f0:	84 c0                	test   %al,%al
c00225f2:	75 3e                	jne    c0022632 <lock_try_acquire+0x5b>
  success = sema_try_down (&lock->semaphore);
c00225f4:	83 ec 0c             	sub    $0xc,%esp
c00225f7:	8d 43 04             	lea    0x4(%ebx),%eax
c00225fa:	50                   	push   %eax
c00225fb:	e8 54 fd ff ff       	call   c0022354 <sema_try_down>
c0022600:	89 c6                	mov    %eax,%esi
  if (success)
c0022602:	83 c4 10             	add    $0x10,%esp
c0022605:	84 c0                	test   %al,%al
c0022607:	75 4a                	jne    c0022653 <lock_try_acquire+0x7c>
}
c0022609:	89 f0                	mov    %esi,%eax
c002260b:	83 c4 04             	add    $0x4,%esp
c002260e:	5b                   	pop    %ebx
c002260f:	5e                   	pop    %esi
c0022610:	c3                   	ret    
  ASSERT (lock != NULL);
c0022611:	83 ec 0c             	sub    $0xc,%esp
c0022614:	68 5f d6 02 c0       	push   $0xc002d65f
c0022619:	68 9f cd 02 c0       	push   $0xc002cd9f
c002261e:	68 74 b8 02 c0       	push   $0xc002b874
c0022623:	68 d6 00 00 00       	push   $0xd6
c0022628:	68 23 d6 02 c0       	push   $0xc002d623
c002262d:	e8 dd 51 00 00       	call   c002780f <debug_panic>
  ASSERT (!lock_held_by_current_thread (lock));
c0022632:	83 ec 0c             	sub    $0xc,%esp
c0022635:	68 7c d6 02 c0       	push   $0xc002d67c
c002263a:	68 9f cd 02 c0       	push   $0xc002cd9f
c002263f:	68 74 b8 02 c0       	push   $0xc002b874
c0022644:	68 d7 00 00 00       	push   $0xd7
c0022649:	68 23 d6 02 c0       	push   $0xc002d623
c002264e:	e8 bc 51 00 00       	call   c002780f <debug_panic>
    lock->holder = thread_current ();
c0022653:	e8 f7 e4 ff ff       	call   c0020b4f <thread_current>
c0022658:	89 03                	mov    %eax,(%ebx)
  return success;
c002265a:	eb ad                	jmp    c0022609 <lock_try_acquire+0x32>

c002265c <lock_release>:
{
c002265c:	53                   	push   %ebx
c002265d:	83 ec 08             	sub    $0x8,%esp
c0022660:	8b 5c 24 10          	mov    0x10(%esp),%ebx
  ASSERT (lock != NULL);
c0022664:	85 db                	test   %ebx,%ebx
c0022666:	74 27                	je     c002268f <lock_release+0x33>
  ASSERT (lock_held_by_current_thread (lock));
c0022668:	83 ec 0c             	sub    $0xc,%esp
c002266b:	53                   	push   %ebx
c002266c:	e8 88 fe ff ff       	call   c00224f9 <lock_held_by_current_thread>
c0022671:	83 c4 10             	add    $0x10,%esp
c0022674:	84 c0                	test   %al,%al
c0022676:	74 38                	je     c00226b0 <lock_release+0x54>
  lock->holder = NULL;
c0022678:	c7 03 00 00 00 00    	movl   $0x0,(%ebx)
  sema_up (&lock->semaphore);
c002267e:	83 ec 0c             	sub    $0xc,%esp
c0022681:	83 c3 04             	add    $0x4,%ebx
c0022684:	53                   	push   %ebx
c0022685:	e8 18 fd ff ff       	call   c00223a2 <sema_up>
}
c002268a:	83 c4 18             	add    $0x18,%esp
c002268d:	5b                   	pop    %ebx
c002268e:	c3                   	ret    
  ASSERT (lock != NULL);
c002268f:	83 ec 0c             	sub    $0xc,%esp
c0022692:	68 5f d6 02 c0       	push   $0xc002d65f
c0022697:	68 9f cd 02 c0       	push   $0xc002cd9f
c002269c:	68 64 b8 02 c0       	push   $0xc002b864
c00226a1:	68 e7 00 00 00       	push   $0xe7
c00226a6:	68 23 d6 02 c0       	push   $0xc002d623
c00226ab:	e8 5f 51 00 00       	call   c002780f <debug_panic>
  ASSERT (lock_held_by_current_thread (lock));
c00226b0:	83 ec 0c             	sub    $0xc,%esp
c00226b3:	68 a0 d6 02 c0       	push   $0xc002d6a0
c00226b8:	68 9f cd 02 c0       	push   $0xc002cd9f
c00226bd:	68 64 b8 02 c0       	push   $0xc002b864
c00226c2:	68 e8 00 00 00       	push   $0xe8
c00226c7:	68 23 d6 02 c0       	push   $0xc002d623
c00226cc:	e8 3e 51 00 00       	call   c002780f <debug_panic>

c00226d1 <cond_init>:
/* Initializes condition variable COND.  A condition variable
   allows one piece of code to signal a condition and cooperating
   code to receive the signal and act upon it. */
void
cond_init (struct condition *cond)
{
c00226d1:	83 ec 0c             	sub    $0xc,%esp
c00226d4:	8b 44 24 10          	mov    0x10(%esp),%eax
  ASSERT (cond != NULL);
c00226d8:	85 c0                	test   %eax,%eax
c00226da:	74 0d                	je     c00226e9 <cond_init+0x18>

  list_init (&cond->waiters);
c00226dc:	83 ec 0c             	sub    $0xc,%esp
c00226df:	50                   	push   %eax
c00226e0:	e8 d1 51 00 00       	call   c00278b6 <list_init>
}
c00226e5:	83 c4 1c             	add    $0x1c,%esp
c00226e8:	c3                   	ret    
  ASSERT (cond != NULL);
c00226e9:	83 ec 0c             	sub    $0xc,%esp
c00226ec:	68 6c d6 02 c0       	push   $0xc002d66c
c00226f1:	68 9f cd 02 c0       	push   $0xc002cd9f
c00226f6:	68 3c b8 02 c0       	push   $0xc002b83c
c00226fb:	68 06 01 00 00       	push   $0x106
c0022700:	68 23 d6 02 c0       	push   $0xc002d623
c0022705:	e8 05 51 00 00       	call   c002780f <debug_panic>

c002270a <cond_wait>:
   interrupt handler.  This function may be called with
   interrupts disabled, but interrupts will be turned back on if
   we need to sleep. */
void
cond_wait (struct condition *cond, struct lock *lock) 
{
c002270a:	55                   	push   %ebp
c002270b:	57                   	push   %edi
c002270c:	56                   	push   %esi
c002270d:	53                   	push   %ebx
c002270e:	83 ec 2c             	sub    $0x2c,%esp
c0022711:	8b 74 24 40          	mov    0x40(%esp),%esi
c0022715:	8b 5c 24 44          	mov    0x44(%esp),%ebx
  struct semaphore_elem waiter;

  ASSERT (cond != NULL);
c0022719:	85 f6                	test   %esi,%esi
c002271b:	74 62                	je     c002277f <cond_wait+0x75>
  ASSERT (lock != NULL);
c002271d:	85 db                	test   %ebx,%ebx
c002271f:	74 7f                	je     c00227a0 <cond_wait+0x96>
  ASSERT (!intr_context ());
c0022721:	e8 4f ed ff ff       	call   c0021475 <intr_context>
c0022726:	84 c0                	test   %al,%al
c0022728:	0f 85 93 00 00 00    	jne    c00227c1 <cond_wait+0xb7>
  ASSERT (lock_held_by_current_thread (lock));
c002272e:	83 ec 0c             	sub    $0xc,%esp
c0022731:	53                   	push   %ebx
c0022732:	e8 c2 fd ff ff       	call   c00224f9 <lock_held_by_current_thread>
c0022737:	83 c4 10             	add    $0x10,%esp
c002273a:	84 c0                	test   %al,%al
c002273c:	0f 84 a0 00 00 00    	je     c00227e2 <cond_wait+0xd8>
  
  sema_init (&waiter.semaphore, 0);
c0022742:	83 ec 08             	sub    $0x8,%esp
c0022745:	6a 00                	push   $0x0
c0022747:	8d 6c 24 10          	lea    0x10(%esp),%ebp
c002274b:	8d 7c 24 18          	lea    0x18(%esp),%edi
c002274f:	57                   	push   %edi
c0022750:	e8 2d fb ff ff       	call   c0022282 <sema_init>
  list_push_back (&cond->waiters, &waiter.elem);
c0022755:	83 c4 08             	add    $0x8,%esp
c0022758:	55                   	push   %ebp
c0022759:	56                   	push   %esi
c002275a:	e8 f4 55 00 00       	call   c0027d53 <list_push_back>
  lock_release (lock);
c002275f:	89 1c 24             	mov    %ebx,(%esp)
c0022762:	e8 f5 fe ff ff       	call   c002265c <lock_release>
  sema_down (&waiter.semaphore);
c0022767:	89 3c 24             	mov    %edi,(%esp)
c002276a:	e8 52 fb ff ff       	call   c00222c1 <sema_down>
  lock_acquire (lock);
c002276f:	89 1c 24             	mov    %ebx,(%esp)
c0022772:	e8 c0 fd ff ff       	call   c0022537 <lock_acquire>
}
c0022777:	83 c4 3c             	add    $0x3c,%esp
c002277a:	5b                   	pop    %ebx
c002277b:	5e                   	pop    %esi
c002277c:	5f                   	pop    %edi
c002277d:	5d                   	pop    %ebp
c002277e:	c3                   	ret    
  ASSERT (cond != NULL);
c002277f:	83 ec 0c             	sub    $0xc,%esp
c0022782:	68 6c d6 02 c0       	push   $0xc002d66c
c0022787:	68 9f cd 02 c0       	push   $0xc002cd9f
c002278c:	68 30 b8 02 c0       	push   $0xc002b830
c0022791:	68 24 01 00 00       	push   $0x124
c0022796:	68 23 d6 02 c0       	push   $0xc002d623
c002279b:	e8 6f 50 00 00       	call   c002780f <debug_panic>
  ASSERT (lock != NULL);
c00227a0:	83 ec 0c             	sub    $0xc,%esp
c00227a3:	68 5f d6 02 c0       	push   $0xc002d65f
c00227a8:	68 9f cd 02 c0       	push   $0xc002cd9f
c00227ad:	68 30 b8 02 c0       	push   $0xc002b830
c00227b2:	68 25 01 00 00       	push   $0x125
c00227b7:	68 23 d6 02 c0       	push   $0xc002d623
c00227bc:	e8 4e 50 00 00       	call   c002780f <debug_panic>
  ASSERT (!intr_context ());
c00227c1:	83 ec 0c             	sub    $0xc,%esp
c00227c4:	68 cc d1 02 c0       	push   $0xc002d1cc
c00227c9:	68 9f cd 02 c0       	push   $0xc002cd9f
c00227ce:	68 30 b8 02 c0       	push   $0xc002b830
c00227d3:	68 26 01 00 00       	push   $0x126
c00227d8:	68 23 d6 02 c0       	push   $0xc002d623
c00227dd:	e8 2d 50 00 00       	call   c002780f <debug_panic>
  ASSERT (lock_held_by_current_thread (lock));
c00227e2:	83 ec 0c             	sub    $0xc,%esp
c00227e5:	68 a0 d6 02 c0       	push   $0xc002d6a0
c00227ea:	68 9f cd 02 c0       	push   $0xc002cd9f
c00227ef:	68 30 b8 02 c0       	push   $0xc002b830
c00227f4:	68 27 01 00 00       	push   $0x127
c00227f9:	68 23 d6 02 c0       	push   $0xc002d623
c00227fe:	e8 0c 50 00 00       	call   c002780f <debug_panic>

c0022803 <cond_signal>:
   An interrupt handler cannot acquire a lock, so it does not
   make sense to try to signal a condition variable within an
   interrupt handler. */
void
cond_signal (struct condition *cond, struct lock *lock UNUSED) 
{
c0022803:	56                   	push   %esi
c0022804:	53                   	push   %ebx
c0022805:	83 ec 04             	sub    $0x4,%esp
c0022808:	8b 5c 24 10          	mov    0x10(%esp),%ebx
c002280c:	8b 74 24 14          	mov    0x14(%esp),%esi
  ASSERT (cond != NULL);
c0022810:	85 db                	test   %ebx,%ebx
c0022812:	74 37                	je     c002284b <cond_signal+0x48>
  ASSERT (lock != NULL);
c0022814:	85 f6                	test   %esi,%esi
c0022816:	74 54                	je     c002286c <cond_signal+0x69>
  ASSERT (!intr_context ());
c0022818:	e8 58 ec ff ff       	call   c0021475 <intr_context>
c002281d:	84 c0                	test   %al,%al
c002281f:	75 6c                	jne    c002288d <cond_signal+0x8a>
  ASSERT (lock_held_by_current_thread (lock));
c0022821:	83 ec 0c             	sub    $0xc,%esp
c0022824:	56                   	push   %esi
c0022825:	e8 cf fc ff ff       	call   c00224f9 <lock_held_by_current_thread>
c002282a:	83 c4 10             	add    $0x10,%esp
c002282d:	84 c0                	test   %al,%al
c002282f:	74 7d                	je     c00228ae <cond_signal+0xab>

  if (!list_empty (&cond->waiters)) 
c0022831:	83 ec 0c             	sub    $0xc,%esp
c0022834:	53                   	push   %ebx
c0022835:	e8 c1 55 00 00       	call   c0027dfb <list_empty>
c002283a:	83 c4 10             	add    $0x10,%esp
c002283d:	84 c0                	test   %al,%al
c002283f:	0f 84 8a 00 00 00    	je     c00228cf <cond_signal+0xcc>
    sema_up (&list_entry (list_pop_front (&cond->waiters),
                          struct semaphore_elem, elem)->semaphore);
}
c0022845:	83 c4 04             	add    $0x4,%esp
c0022848:	5b                   	pop    %ebx
c0022849:	5e                   	pop    %esi
c002284a:	c3                   	ret    
  ASSERT (cond != NULL);
c002284b:	83 ec 0c             	sub    $0xc,%esp
c002284e:	68 6c d6 02 c0       	push   $0xc002d66c
c0022853:	68 9f cd 02 c0       	push   $0xc002cd9f
c0022858:	68 24 b8 02 c0       	push   $0xc002b824
c002285d:	68 3a 01 00 00       	push   $0x13a
c0022862:	68 23 d6 02 c0       	push   $0xc002d623
c0022867:	e8 a3 4f 00 00       	call   c002780f <debug_panic>
  ASSERT (lock != NULL);
c002286c:	83 ec 0c             	sub    $0xc,%esp
c002286f:	68 5f d6 02 c0       	push   $0xc002d65f
c0022874:	68 9f cd 02 c0       	push   $0xc002cd9f
c0022879:	68 24 b8 02 c0       	push   $0xc002b824
c002287e:	68 3b 01 00 00       	push   $0x13b
c0022883:	68 23 d6 02 c0       	push   $0xc002d623
c0022888:	e8 82 4f 00 00       	call   c002780f <debug_panic>
  ASSERT (!intr_context ());
c002288d:	83 ec 0c             	sub    $0xc,%esp
c0022890:	68 cc d1 02 c0       	push   $0xc002d1cc
c0022895:	68 9f cd 02 c0       	push   $0xc002cd9f
c002289a:	68 24 b8 02 c0       	push   $0xc002b824
c002289f:	68 3c 01 00 00       	push   $0x13c
c00228a4:	68 23 d6 02 c0       	push   $0xc002d623
c00228a9:	e8 61 4f 00 00       	call   c002780f <debug_panic>
  ASSERT (lock_held_by_current_thread (lock));
c00228ae:	83 ec 0c             	sub    $0xc,%esp
c00228b1:	68 a0 d6 02 c0       	push   $0xc002d6a0
c00228b6:	68 9f cd 02 c0       	push   $0xc002cd9f
c00228bb:	68 24 b8 02 c0       	push   $0xc002b824
c00228c0:	68 3d 01 00 00       	push   $0x13d
c00228c5:	68 23 d6 02 c0       	push   $0xc002d623
c00228ca:	e8 40 4f 00 00       	call   c002780f <debug_panic>
    sema_up (&list_entry (list_pop_front (&cond->waiters),
c00228cf:	83 ec 0c             	sub    $0xc,%esp
c00228d2:	53                   	push   %ebx
c00228d3:	e8 85 55 00 00       	call   c0027e5d <list_pop_front>
c00228d8:	83 c0 08             	add    $0x8,%eax
c00228db:	89 04 24             	mov    %eax,(%esp)
c00228de:	e8 bf fa ff ff       	call   c00223a2 <sema_up>
c00228e3:	83 c4 10             	add    $0x10,%esp
}
c00228e6:	e9 5a ff ff ff       	jmp    c0022845 <cond_signal+0x42>

c00228eb <cond_broadcast>:
   An interrupt handler cannot acquire a lock, so it does not
   make sense to try to signal a condition variable within an
   interrupt handler. */
void
cond_broadcast (struct condition *cond, struct lock *lock) 
{
c00228eb:	56                   	push   %esi
c00228ec:	53                   	push   %ebx
c00228ed:	83 ec 04             	sub    $0x4,%esp
c00228f0:	8b 5c 24 10          	mov    0x10(%esp),%ebx
c00228f4:	8b 74 24 14          	mov    0x14(%esp),%esi
  ASSERT (cond != NULL);
c00228f8:	85 db                	test   %ebx,%ebx
c00228fa:	74 25                	je     c0022921 <cond_broadcast+0x36>
  ASSERT (lock != NULL);
c00228fc:	85 f6                	test   %esi,%esi
c00228fe:	75 4f                	jne    c002294f <cond_broadcast+0x64>
c0022900:	83 ec 0c             	sub    $0xc,%esp
c0022903:	68 5f d6 02 c0       	push   $0xc002d65f
c0022908:	68 9f cd 02 c0       	push   $0xc002cd9f
c002290d:	68 14 b8 02 c0       	push   $0xc002b814
c0022912:	68 4e 01 00 00       	push   $0x14e
c0022917:	68 23 d6 02 c0       	push   $0xc002d623
c002291c:	e8 ee 4e 00 00       	call   c002780f <debug_panic>
  ASSERT (cond != NULL);
c0022921:	83 ec 0c             	sub    $0xc,%esp
c0022924:	68 6c d6 02 c0       	push   $0xc002d66c
c0022929:	68 9f cd 02 c0       	push   $0xc002cd9f
c002292e:	68 14 b8 02 c0       	push   $0xc002b814
c0022933:	68 4d 01 00 00       	push   $0x14d
c0022938:	68 23 d6 02 c0       	push   $0xc002d623
c002293d:	e8 cd 4e 00 00       	call   c002780f <debug_panic>

  while (!list_empty (&cond->waiters))
    cond_signal (cond, lock);
c0022942:	83 ec 08             	sub    $0x8,%esp
c0022945:	56                   	push   %esi
c0022946:	53                   	push   %ebx
c0022947:	e8 b7 fe ff ff       	call   c0022803 <cond_signal>
c002294c:	83 c4 10             	add    $0x10,%esp
  while (!list_empty (&cond->waiters))
c002294f:	83 ec 0c             	sub    $0xc,%esp
c0022952:	53                   	push   %ebx
c0022953:	e8 a3 54 00 00       	call   c0027dfb <list_empty>
c0022958:	83 c4 10             	add    $0x10,%esp
c002295b:	84 c0                	test   %al,%al
c002295d:	74 e3                	je     c0022942 <cond_broadcast+0x57>
}
c002295f:	83 c4 04             	add    $0x4,%esp
c0022962:	5b                   	pop    %ebx
c0022963:	5e                   	pop    %esi
c0022964:	c3                   	ret    

c0022965 <init_pool>:

/* Initializes pool P as starting at START and ending at END,
   naming it NAME for debugging purposes. */
static void
init_pool (struct pool *p, void *base, size_t page_cnt, const char *name) 
{
c0022965:	55                   	push   %ebp
c0022966:	57                   	push   %edi
c0022967:	56                   	push   %esi
c0022968:	53                   	push   %ebx
c0022969:	83 ec 18             	sub    $0x18,%esp
c002296c:	89 c5                	mov    %eax,%ebp
c002296e:	89 d7                	mov    %edx,%edi
c0022970:	89 ce                	mov    %ecx,%esi
  /* We'll put the pool's used_map at its base.
     Calculate the space needed for the bitmap
     and subtract it from the pool's size. */
  size_t bm_pages = DIV_ROUND_UP (bitmap_buf_size (page_cnt), PGSIZE);
c0022972:	51                   	push   %ecx
c0022973:	e8 fa 5a 00 00       	call   c0028472 <bitmap_buf_size>
c0022978:	8d 98 ff 0f 00 00    	lea    0xfff(%eax),%ebx
c002297e:	89 d8                	mov    %ebx,%eax
c0022980:	c1 e8 0c             	shr    $0xc,%eax
  if (bm_pages > page_cnt)
c0022983:	83 c4 10             	add    $0x10,%esp
c0022986:	39 c6                	cmp    %eax,%esi
c0022988:	72 3d                	jb     c00229c7 <init_pool+0x62>
    PANIC ("Not enough memory in %s for bitmap.", name);
  page_cnt -= bm_pages;
c002298a:	29 c6                	sub    %eax,%esi

  printf ("%zu pages available in %s.\n", page_cnt, name);
c002298c:	83 ec 04             	sub    $0x4,%esp
c002298f:	ff 74 24 24          	pushl  0x24(%esp)
c0022993:	56                   	push   %esi
c0022994:	68 2f d7 02 c0       	push   $0xc002d72f
c0022999:	e8 c3 33 00 00       	call   c0025d61 <printf>

  /* Initialize the pool. */
  lock_init (&p->lock);
c002299e:	89 2c 24             	mov    %ebp,(%esp)
c00229a1:	e8 0f fb ff ff       	call   c00224b5 <lock_init>
  p->used_map = bitmap_create_in_buf (page_cnt, base, bm_pages * PGSIZE);
c00229a6:	81 e3 00 f0 ff ff    	and    $0xfffff000,%ebx
c00229ac:	83 c4 0c             	add    $0xc,%esp
c00229af:	53                   	push   %ebx
c00229b0:	57                   	push   %edi
c00229b1:	56                   	push   %esi
c00229b2:	e8 94 5d 00 00       	call   c002874b <bitmap_create_in_buf>
c00229b7:	89 45 18             	mov    %eax,0x18(%ebp)
  p->base = base + bm_pages * PGSIZE;
c00229ba:	01 df                	add    %ebx,%edi
c00229bc:	89 7d 1c             	mov    %edi,0x1c(%ebp)
}
c00229bf:	83 c4 1c             	add    $0x1c,%esp
c00229c2:	5b                   	pop    %ebx
c00229c3:	5e                   	pop    %esi
c00229c4:	5f                   	pop    %edi
c00229c5:	5d                   	pop    %ebp
c00229c6:	c3                   	ret    
    PANIC ("Not enough memory in %s for bitmap.", name);
c00229c7:	83 ec 0c             	sub    $0xc,%esp
c00229ca:	ff 74 24 2c          	pushl  0x2c(%esp)
c00229ce:	68 c4 d6 02 c0       	push   $0xc002d6c4
c00229d3:	68 00 b9 02 c0       	push   $0xc002b900
c00229d8:	68 a1 00 00 00       	push   $0xa1
c00229dd:	68 18 d7 02 c0       	push   $0xc002d718
c00229e2:	e8 28 4e 00 00       	call   c002780f <debug_panic>

c00229e7 <palloc_init>:
{
c00229e7:	56                   	push   %esi
c00229e8:	53                   	push   %ebx
c00229e9:	83 ec 04             	sub    $0x4,%esp
  uint8_t *free_end = ptov (init_ram_pages * PGSIZE);
c00229ec:	a1 5e 01 02 c0       	mov    0xc002015e,%eax
c00229f1:	c1 e0 0c             	shl    $0xc,%eax
  ASSERT ((void *) paddr < PHYS_BASE);
c00229f4:	3d ff ff ff bf       	cmp    $0xbfffffff,%eax
c00229f9:	77 5b                	ja     c0022a56 <palloc_init+0x6f>
  size_t free_pages = (free_end - free_start) / PGSIZE;
c00229fb:	2d 00 00 10 00       	sub    $0x100000,%eax
c0022a00:	89 c3                	mov    %eax,%ebx
c0022a02:	85 c0                	test   %eax,%eax
c0022a04:	78 6e                	js     c0022a74 <palloc_init+0x8d>
c0022a06:	c1 fb 0c             	sar    $0xc,%ebx
  size_t user_pages = free_pages / 2;
c0022a09:	89 d8                	mov    %ebx,%eax
c0022a0b:	d1 e8                	shr    %eax
c0022a0d:	89 c6                	mov    %eax,%esi
c0022a0f:	3b 44 24 10          	cmp    0x10(%esp),%eax
c0022a13:	76 04                	jbe    c0022a19 <palloc_init+0x32>
c0022a15:	8b 74 24 10          	mov    0x10(%esp),%esi
  kernel_pages = free_pages - user_pages;
c0022a19:	29 f3                	sub    %esi,%ebx
  init_pool (&kernel_pool, free_start, kernel_pages, "kernel pool");
c0022a1b:	83 ec 0c             	sub    $0xc,%esp
c0022a1e:	68 66 d7 02 c0       	push   $0xc002d766
c0022a23:	89 d9                	mov    %ebx,%ecx
c0022a25:	ba 00 00 10 c0       	mov    $0xc0100000,%edx
c0022a2a:	b8 e0 7e 03 c0       	mov    $0xc0037ee0,%eax
c0022a2f:	e8 31 ff ff ff       	call   c0022965 <init_pool>
  init_pool (&user_pool, free_start + kernel_pages * PGSIZE,
c0022a34:	c1 e3 0c             	shl    $0xc,%ebx
c0022a37:	8d 93 00 00 10 c0    	lea    -0x3ff00000(%ebx),%edx
c0022a3d:	c7 04 24 72 d7 02 c0 	movl   $0xc002d772,(%esp)
c0022a44:	89 f1                	mov    %esi,%ecx
c0022a46:	b8 c0 7e 03 c0       	mov    $0xc0037ec0,%eax
c0022a4b:	e8 15 ff ff ff       	call   c0022965 <init_pool>
}
c0022a50:	83 c4 14             	add    $0x14,%esp
c0022a53:	5b                   	pop    %ebx
c0022a54:	5e                   	pop    %esi
c0022a55:	c3                   	ret    
c0022a56:	83 ec 0c             	sub    $0xc,%esp
c0022a59:	68 4b d7 02 c0       	push   $0xc002d74b
c0022a5e:	68 9f cd 02 c0       	push   $0xc002cd9f
c0022a63:	68 0c b9 02 c0       	push   $0xc002b90c
c0022a68:	6a 4a                	push   $0x4a
c0022a6a:	68 e2 cd 02 c0       	push   $0xc002cde2
c0022a6f:	e8 9b 4d 00 00       	call   c002780f <debug_panic>
  size_t free_pages = (free_end - free_start) / PGSIZE;
c0022a74:	8d 98 ff 0f 00 00    	lea    0xfff(%eax),%ebx
c0022a7a:	eb 8a                	jmp    c0022a06 <palloc_init+0x1f>

c0022a7c <palloc_get_multiple>:
{
c0022a7c:	57                   	push   %edi
c0022a7d:	56                   	push   %esi
c0022a7e:	53                   	push   %ebx
c0022a7f:	8b 7c 24 14          	mov    0x14(%esp),%edi
  struct pool *pool = flags & PAL_USER ? &user_pool : &kernel_pool;
c0022a83:	f6 44 24 10 04       	testb  $0x4,0x10(%esp)
c0022a88:	75 47                	jne    c0022ad1 <palloc_get_multiple+0x55>
c0022a8a:	bb e0 7e 03 c0       	mov    $0xc0037ee0,%ebx
  if (page_cnt == 0)
c0022a8f:	85 ff                	test   %edi,%edi
c0022a91:	74 76                	je     c0022b09 <palloc_get_multiple+0x8d>
  lock_acquire (&pool->lock);
c0022a93:	83 ec 0c             	sub    $0xc,%esp
c0022a96:	53                   	push   %ebx
c0022a97:	e8 9b fa ff ff       	call   c0022537 <lock_acquire>
  page_idx = bitmap_scan_and_flip (pool->used_map, 0, page_cnt, false);
c0022a9c:	6a 00                	push   $0x0
c0022a9e:	57                   	push   %edi
c0022a9f:	6a 00                	push   $0x0
c0022aa1:	ff 73 18             	pushl  0x18(%ebx)
c0022aa4:	e8 71 5f 00 00       	call   c0028a1a <bitmap_scan_and_flip>
c0022aa9:	89 c6                	mov    %eax,%esi
  lock_release (&pool->lock);
c0022aab:	83 c4 14             	add    $0x14,%esp
c0022aae:	53                   	push   %ebx
c0022aaf:	e8 a8 fb ff ff       	call   c002265c <lock_release>
  if (page_idx != BITMAP_ERROR)
c0022ab4:	83 c4 10             	add    $0x10,%esp
c0022ab7:	83 fe ff             	cmp    $0xffffffff,%esi
c0022aba:	74 29                	je     c0022ae5 <palloc_get_multiple+0x69>
    pages = pool->base + PGSIZE * page_idx;
c0022abc:	c1 e6 0c             	shl    $0xc,%esi
  if (pages != NULL) 
c0022abf:	03 73 1c             	add    0x1c(%ebx),%esi
c0022ac2:	74 21                	je     c0022ae5 <palloc_get_multiple+0x69>
      if (flags & PAL_ZERO)
c0022ac4:	f6 44 24 10 02       	testb  $0x2,0x10(%esp)
c0022ac9:	75 0d                	jne    c0022ad8 <palloc_get_multiple+0x5c>
}
c0022acb:	89 f0                	mov    %esi,%eax
c0022acd:	5b                   	pop    %ebx
c0022ace:	5e                   	pop    %esi
c0022acf:	5f                   	pop    %edi
c0022ad0:	c3                   	ret    
  struct pool *pool = flags & PAL_USER ? &user_pool : &kernel_pool;
c0022ad1:	bb c0 7e 03 c0       	mov    $0xc0037ec0,%ebx
c0022ad6:	eb b7                	jmp    c0022a8f <palloc_get_multiple+0x13>
        memset (pages, 0, PGSIZE * page_cnt);
c0022ad8:	89 f9                	mov    %edi,%ecx
c0022ada:	c1 e1 0c             	shl    $0xc,%ecx
c0022add:	b0 00                	mov    $0x0,%al
c0022adf:	89 f7                	mov    %esi,%edi
c0022ae1:	f3 aa                	rep stos %al,%es:(%edi)
c0022ae3:	eb e6                	jmp    c0022acb <palloc_get_multiple+0x4f>
      if (flags & PAL_ASSERT)
c0022ae5:	f6 44 24 10 01       	testb  $0x1,0x10(%esp)
c0022aea:	75 07                	jne    c0022af3 <palloc_get_multiple+0x77>
  return pages;
c0022aec:	be 00 00 00 00       	mov    $0x0,%esi
c0022af1:	eb d8                	jmp    c0022acb <palloc_get_multiple+0x4f>
        PANIC ("palloc_get: out of pages");
c0022af3:	68 7c d7 02 c0       	push   $0xc002d77c
c0022af8:	68 ec b8 02 c0       	push   $0xc002b8ec
c0022afd:	6a 61                	push   $0x61
c0022aff:	68 18 d7 02 c0       	push   $0xc002d718
c0022b04:	e8 06 4d 00 00       	call   c002780f <debug_panic>
    return NULL;
c0022b09:	be 00 00 00 00       	mov    $0x0,%esi
c0022b0e:	eb bb                	jmp    c0022acb <palloc_get_multiple+0x4f>

c0022b10 <palloc_get_page>:
{
c0022b10:	83 ec 14             	sub    $0x14,%esp
  return palloc_get_multiple (flags, 1);
c0022b13:	6a 01                	push   $0x1
c0022b15:	ff 74 24 1c          	pushl  0x1c(%esp)
c0022b19:	e8 5e ff ff ff       	call   c0022a7c <palloc_get_multiple>
}
c0022b1e:	83 c4 1c             	add    $0x1c,%esp
c0022b21:	c3                   	ret    

c0022b22 <palloc_free_multiple>:
{
c0022b22:	55                   	push   %ebp
c0022b23:	57                   	push   %edi
c0022b24:	56                   	push   %esi
c0022b25:	53                   	push   %ebx
c0022b26:	83 ec 0c             	sub    $0xc,%esp
c0022b29:	8b 5c 24 24          	mov    0x24(%esp),%ebx
  ASSERT (pg_ofs (pages) == 0);
c0022b2d:	f7 44 24 20 ff 0f 00 	testl  $0xfff,0x20(%esp)
c0022b34:	00 
c0022b35:	75 13                	jne    c0022b4a <palloc_free_multiple+0x28>
  if (pages == NULL || page_cnt == 0)
c0022b37:	83 7c 24 20 00       	cmpl   $0x0,0x20(%esp)
c0022b3c:	74 04                	je     c0022b42 <palloc_free_multiple+0x20>
c0022b3e:	85 db                	test   %ebx,%ebx
c0022b40:	75 26                	jne    c0022b68 <palloc_free_multiple+0x46>
}
c0022b42:	83 c4 0c             	add    $0xc,%esp
c0022b45:	5b                   	pop    %ebx
c0022b46:	5e                   	pop    %esi
c0022b47:	5f                   	pop    %edi
c0022b48:	5d                   	pop    %ebp
c0022b49:	c3                   	ret    
  ASSERT (pg_ofs (pages) == 0);
c0022b4a:	83 ec 0c             	sub    $0xc,%esp
c0022b4d:	68 95 d7 02 c0       	push   $0xc002d795
c0022b52:	68 9f cd 02 c0       	push   $0xc002cd9f
c0022b57:	68 d4 b8 02 c0       	push   $0xc002b8d4
c0022b5c:	6a 7b                	push   $0x7b
c0022b5e:	68 18 d7 02 c0       	push   $0xc002d718
c0022b63:	e8 a7 4c 00 00       	call   c002780f <debug_panic>
  return (uintptr_t) va >> PGBITS;
c0022b68:	8b 74 24 20          	mov    0x20(%esp),%esi
c0022b6c:	c1 ee 0c             	shr    $0xc,%esi
c0022b6f:	8b 2d fc 7e 03 c0    	mov    0xc0037efc,%ebp
c0022b75:	c1 ed 0c             	shr    $0xc,%ebp
static bool
page_from_pool (const struct pool *pool, void *page) 
{
  size_t page_no = pg_no (page);
  size_t start_page = pg_no (pool->base);
  size_t end_page = start_page + bitmap_size (pool->used_map);
c0022b78:	83 ec 0c             	sub    $0xc,%esp
c0022b7b:	ff 35 f8 7e 03 c0    	pushl  0xc0037ef8
c0022b81:	e8 25 59 00 00       	call   c00284ab <bitmap_size>

  return page_no >= start_page && page_no < end_page;
c0022b86:	83 c4 10             	add    $0x10,%esp
c0022b89:	39 ee                	cmp    %ebp,%esi
c0022b8b:	72 06                	jb     c0022b93 <palloc_free_multiple+0x71>
  size_t end_page = start_page + bitmap_size (pool->used_map);
c0022b8d:	01 c5                	add    %eax,%ebp
  return page_no >= start_page && page_no < end_page;
c0022b8f:	39 ee                	cmp    %ebp,%esi
c0022b91:	72 44                	jb     c0022bd7 <palloc_free_multiple+0xb5>
c0022b93:	8b 2d dc 7e 03 c0    	mov    0xc0037edc,%ebp
c0022b99:	c1 ed 0c             	shr    $0xc,%ebp
  size_t end_page = start_page + bitmap_size (pool->used_map);
c0022b9c:	83 ec 0c             	sub    $0xc,%esp
c0022b9f:	ff 35 d8 7e 03 c0    	pushl  0xc0037ed8
c0022ba5:	e8 01 59 00 00       	call   c00284ab <bitmap_size>
  return page_no >= start_page && page_no < end_page;
c0022baa:	83 c4 10             	add    $0x10,%esp
c0022bad:	39 ee                	cmp    %ebp,%esi
c0022baf:	73 19                	jae    c0022bca <palloc_free_multiple+0xa8>
    NOT_REACHED ();
c0022bb1:	68 4c d2 02 c0       	push   $0xc002d24c
c0022bb6:	68 d4 b8 02 c0       	push   $0xc002b8d4
c0022bbb:	68 84 00 00 00       	push   $0x84
c0022bc0:	68 18 d7 02 c0       	push   $0xc002d718
c0022bc5:	e8 45 4c 00 00       	call   c002780f <debug_panic>
  size_t end_page = start_page + bitmap_size (pool->used_map);
c0022bca:	01 e8                	add    %ebp,%eax
  return page_no >= start_page && page_no < end_page;
c0022bcc:	39 c6                	cmp    %eax,%esi
c0022bce:	73 e1                	jae    c0022bb1 <palloc_free_multiple+0x8f>
    pool = &user_pool;
c0022bd0:	bd c0 7e 03 c0       	mov    $0xc0037ec0,%ebp
c0022bd5:	eb 05                	jmp    c0022bdc <palloc_free_multiple+0xba>
    pool = &kernel_pool;
c0022bd7:	bd e0 7e 03 c0       	mov    $0xc0037ee0,%ebp
c0022bdc:	8b 45 1c             	mov    0x1c(%ebp),%eax
c0022bdf:	c1 e8 0c             	shr    $0xc,%eax
  page_idx = pg_no (pages) - pg_no (pool->base);
c0022be2:	29 c6                	sub    %eax,%esi
  memset (pages, 0xcc, PGSIZE * page_cnt);
c0022be4:	89 d9                	mov    %ebx,%ecx
c0022be6:	c1 e1 0c             	shl    $0xc,%ecx
c0022be9:	b0 cc                	mov    $0xcc,%al
c0022beb:	8b 7c 24 20          	mov    0x20(%esp),%edi
c0022bef:	f3 aa                	rep stos %al,%es:(%edi)
  ASSERT (bitmap_all (pool->used_map, page_idx, page_cnt));
c0022bf1:	83 ec 04             	sub    $0x4,%esp
c0022bf4:	53                   	push   %ebx
c0022bf5:	56                   	push   %esi
c0022bf6:	ff 75 18             	pushl  0x18(%ebp)
c0022bf9:	e8 4f 5d 00 00       	call   c002894d <bitmap_all>
c0022bfe:	83 c4 10             	add    $0x10,%esp
c0022c01:	84 c0                	test   %al,%al
c0022c03:	74 14                	je     c0022c19 <palloc_free_multiple+0xf7>
  bitmap_set_multiple (pool->used_map, page_idx, page_cnt, false);
c0022c05:	6a 00                	push   $0x0
c0022c07:	53                   	push   %ebx
c0022c08:	56                   	push   %esi
c0022c09:	ff 75 18             	pushl  0x18(%ebp)
c0022c0c:	e8 e7 59 00 00       	call   c00285f8 <bitmap_set_multiple>
c0022c11:	83 c4 10             	add    $0x10,%esp
c0022c14:	e9 29 ff ff ff       	jmp    c0022b42 <palloc_free_multiple+0x20>
  ASSERT (bitmap_all (pool->used_map, page_idx, page_cnt));
c0022c19:	83 ec 0c             	sub    $0xc,%esp
c0022c1c:	68 e8 d6 02 c0       	push   $0xc002d6e8
c0022c21:	68 9f cd 02 c0       	push   $0xc002cd9f
c0022c26:	68 d4 b8 02 c0       	push   $0xc002b8d4
c0022c2b:	68 8c 00 00 00       	push   $0x8c
c0022c30:	68 18 d7 02 c0       	push   $0xc002d718
c0022c35:	e8 d5 4b 00 00       	call   c002780f <debug_panic>

c0022c3a <palloc_free_page>:
{
c0022c3a:	83 ec 14             	sub    $0x14,%esp
  palloc_free_multiple (page, 1);
c0022c3d:	6a 01                	push   $0x1
c0022c3f:	ff 74 24 1c          	pushl  0x1c(%esp)
c0022c43:	e8 da fe ff ff       	call   c0022b22 <palloc_free_multiple>
}
c0022c48:	83 c4 1c             	add    $0x1c,%esp
c0022c4b:	c3                   	ret    

c0022c4c <arena_to_block>:
}

/* Returns the (IDX - 1)'th block within arena A. */
static struct block *
arena_to_block (struct arena *a, size_t idx) 
{
c0022c4c:	83 ec 0c             	sub    $0xc,%esp
  ASSERT (a != NULL);
c0022c4f:	85 c0                	test   %eax,%eax
c0022c51:	74 1b                	je     c0022c6e <arena_to_block+0x22>
  ASSERT (a->magic == ARENA_MAGIC);
c0022c53:	81 38 ed 8e 54 9a    	cmpl   $0x9a548eed,(%eax)
c0022c59:	75 34                	jne    c0022c8f <arena_to_block+0x43>
  ASSERT (idx < a->desc->blocks_per_arena);
c0022c5b:	8b 48 04             	mov    0x4(%eax),%ecx
c0022c5e:	39 51 04             	cmp    %edx,0x4(%ecx)
c0022c61:	76 4d                	jbe    c0022cb0 <arena_to_block+0x64>
  return (struct block *) ((uint8_t *) a
                           + sizeof *a
                           + idx * a->desc->block_size);
c0022c63:	0f af 11             	imul   (%ecx),%edx
  return (struct block *) ((uint8_t *) a
c0022c66:	8d 44 10 0c          	lea    0xc(%eax,%edx,1),%eax
}
c0022c6a:	83 c4 0c             	add    $0xc,%esp
c0022c6d:	c3                   	ret    
  ASSERT (a != NULL);
c0022c6e:	83 ec 0c             	sub    $0xc,%esp
c0022c71:	68 19 d6 02 c0       	push   $0xc002d619
c0022c76:	68 9f cd 02 c0       	push   $0xc002cd9f
c0022c7b:	68 2c b9 02 c0       	push   $0xc002b92c
c0022c80:	68 20 01 00 00       	push   $0x120
c0022c85:	68 a9 d7 02 c0       	push   $0xc002d7a9
c0022c8a:	e8 80 4b 00 00       	call   c002780f <debug_panic>
  ASSERT (a->magic == ARENA_MAGIC);
c0022c8f:	83 ec 0c             	sub    $0xc,%esp
c0022c92:	68 c0 d7 02 c0       	push   $0xc002d7c0
c0022c97:	68 9f cd 02 c0       	push   $0xc002cd9f
c0022c9c:	68 2c b9 02 c0       	push   $0xc002b92c
c0022ca1:	68 21 01 00 00       	push   $0x121
c0022ca6:	68 a9 d7 02 c0       	push   $0xc002d7a9
c0022cab:	e8 5f 4b 00 00       	call   c002780f <debug_panic>
  ASSERT (idx < a->desc->blocks_per_arena);
c0022cb0:	83 ec 0c             	sub    $0xc,%esp
c0022cb3:	68 d8 d7 02 c0       	push   $0xc002d7d8
c0022cb8:	68 9f cd 02 c0       	push   $0xc002cd9f
c0022cbd:	68 2c b9 02 c0       	push   $0xc002b92c
c0022cc2:	68 22 01 00 00       	push   $0x122
c0022cc7:	68 a9 d7 02 c0       	push   $0xc002d7a9
c0022ccc:	e8 3e 4b 00 00       	call   c002780f <debug_panic>

c0022cd1 <block_to_arena>:
{
c0022cd1:	53                   	push   %ebx
c0022cd2:	83 ec 08             	sub    $0x8,%esp
  ASSERT (a != NULL);
c0022cd5:	89 c1                	mov    %eax,%ecx
c0022cd7:	81 e1 00 f0 ff ff    	and    $0xfffff000,%ecx
c0022cdd:	74 29                	je     c0022d08 <block_to_arena+0x37>
  ASSERT (a->magic == ARENA_MAGIC);
c0022cdf:	81 39 ed 8e 54 9a    	cmpl   $0x9a548eed,(%ecx)
c0022ce5:	75 42                	jne    c0022d29 <block_to_arena+0x58>
  ASSERT (a->desc == NULL
c0022ce7:	8b 59 04             	mov    0x4(%ecx),%ebx
c0022cea:	85 db                	test   %ebx,%ebx
c0022cec:	74 7d                	je     c0022d6b <block_to_arena+0x9a>
  return (uintptr_t) va & PGMASK;
c0022cee:	25 ff 0f 00 00       	and    $0xfff,%eax
c0022cf3:	83 e8 0c             	sub    $0xc,%eax
c0022cf6:	ba 00 00 00 00       	mov    $0x0,%edx
c0022cfb:	f7 33                	divl   (%ebx)
c0022cfd:	85 d2                	test   %edx,%edx
c0022cff:	75 49                	jne    c0022d4a <block_to_arena+0x79>
}
c0022d01:	89 c8                	mov    %ecx,%eax
c0022d03:	83 c4 08             	add    $0x8,%esp
c0022d06:	5b                   	pop    %ebx
c0022d07:	c3                   	ret    
  ASSERT (a != NULL);
c0022d08:	83 ec 0c             	sub    $0xc,%esp
c0022d0b:	68 19 d6 02 c0       	push   $0xc002d619
c0022d10:	68 9f cd 02 c0       	push   $0xc002cd9f
c0022d15:	68 1c b9 02 c0       	push   $0xc002b91c
c0022d1a:	68 11 01 00 00       	push   $0x111
c0022d1f:	68 a9 d7 02 c0       	push   $0xc002d7a9
c0022d24:	e8 e6 4a 00 00       	call   c002780f <debug_panic>
  ASSERT (a->magic == ARENA_MAGIC);
c0022d29:	83 ec 0c             	sub    $0xc,%esp
c0022d2c:	68 c0 d7 02 c0       	push   $0xc002d7c0
c0022d31:	68 9f cd 02 c0       	push   $0xc002cd9f
c0022d36:	68 1c b9 02 c0       	push   $0xc002b91c
c0022d3b:	68 12 01 00 00       	push   $0x112
c0022d40:	68 a9 d7 02 c0       	push   $0xc002d7a9
c0022d45:	e8 c5 4a 00 00       	call   c002780f <debug_panic>
  ASSERT (a->desc == NULL
c0022d4a:	83 ec 0c             	sub    $0xc,%esp
c0022d4d:	68 f8 d7 02 c0       	push   $0xc002d7f8
c0022d52:	68 9f cd 02 c0       	push   $0xc002cd9f
c0022d57:	68 1c b9 02 c0       	push   $0xc002b91c
c0022d5c:	68 16 01 00 00       	push   $0x116
c0022d61:	68 a9 d7 02 c0       	push   $0xc002d7a9
c0022d66:	e8 a4 4a 00 00       	call   c002780f <debug_panic>
c0022d6b:	25 ff 0f 00 00       	and    $0xfff,%eax
  ASSERT (a->desc != NULL || pg_ofs (b) == sizeof *a);
c0022d70:	83 f8 0c             	cmp    $0xc,%eax
c0022d73:	74 8c                	je     c0022d01 <block_to_arena+0x30>
c0022d75:	83 ec 0c             	sub    $0xc,%esp
c0022d78:	68 40 d8 02 c0       	push   $0xc002d840
c0022d7d:	68 9f cd 02 c0       	push   $0xc002cd9f
c0022d82:	68 1c b9 02 c0       	push   $0xc002b91c
c0022d87:	68 17 01 00 00       	push   $0x117
c0022d8c:	68 a9 d7 02 c0       	push   $0xc002d7a9
c0022d91:	e8 79 4a 00 00       	call   c002780f <debug_panic>

c0022d96 <malloc_init>:
{
c0022d96:	55                   	push   %ebp
c0022d97:	57                   	push   %edi
c0022d98:	56                   	push   %esi
c0022d99:	53                   	push   %ebx
c0022d9a:	83 ec 0c             	sub    $0xc,%esp
      struct desc *d = &descs[desc_cnt++];
c0022d9d:	a1 00 7f 03 c0       	mov    0xc0037f00,%eax
c0022da2:	8d 50 01             	lea    0x1(%eax),%edx
c0022da5:	89 15 00 7f 03 c0    	mov    %edx,0xc0037f00
      ASSERT (desc_cnt <= sizeof descs / sizeof *descs);
c0022dab:	83 fa 0a             	cmp    $0xa,%edx
c0022dae:	0f 87 b0 00 00 00    	ja     c0022e64 <malloc_init+0xce>
      d->block_size = block_size;
c0022db4:	8d 1c 00             	lea    (%eax,%eax,1),%ebx
c0022db7:	8d 14 03             	lea    (%ebx,%eax,1),%edx
c0022dba:	c1 e2 04             	shl    $0x4,%edx
c0022dbd:	c7 82 20 7f 03 c0 10 	movl   $0x10,-0x3ffc80e0(%edx)
c0022dc4:	00 00 00 
      d->blocks_per_arena = (PGSIZE - sizeof (struct arena)) / block_size;
c0022dc7:	c7 82 24 7f 03 c0 ff 	movl   $0xff,-0x3ffc80dc(%edx)
c0022dce:	00 00 00 
c0022dd1:	89 d3                	mov    %edx,%ebx
      list_init (&d->free_list);
c0022dd3:	83 ec 0c             	sub    $0xc,%esp
c0022dd6:	8d 82 28 7f 03 c0    	lea    -0x3ffc80d8(%edx),%eax
c0022ddc:	50                   	push   %eax
c0022ddd:	e8 d4 4a 00 00       	call   c00278b6 <list_init>
      lock_init (&d->lock);
c0022de2:	81 c3 38 7f 03 c0    	add    $0xc0037f38,%ebx
c0022de8:	89 1c 24             	mov    %ebx,(%esp)
c0022deb:	e8 c5 f6 ff ff       	call   c00224b5 <lock_init>
c0022df0:	83 c4 10             	add    $0x10,%esp
  for (block_size = 16; block_size < PGSIZE / 2; block_size *= 2)
c0022df3:	be 20 00 00 00       	mov    $0x20,%esi
      d->blocks_per_arena = (PGSIZE - sizeof (struct arena)) / block_size;
c0022df8:	bf f4 0f 00 00       	mov    $0xff4,%edi
      struct desc *d = &descs[desc_cnt++];
c0022dfd:	8b 0d 00 7f 03 c0    	mov    0xc0037f00,%ecx
c0022e03:	8d 41 01             	lea    0x1(%ecx),%eax
c0022e06:	a3 00 7f 03 c0       	mov    %eax,0xc0037f00
      ASSERT (desc_cnt <= sizeof descs / sizeof *descs);
c0022e0b:	83 f8 0a             	cmp    $0xa,%eax
c0022e0e:	77 54                	ja     c0022e64 <malloc_init+0xce>
      d->block_size = block_size;
c0022e10:	8d 1c 09             	lea    (%ecx,%ecx,1),%ebx
c0022e13:	8d 2c 0b             	lea    (%ebx,%ecx,1),%ebp
c0022e16:	c1 e5 04             	shl    $0x4,%ebp
c0022e19:	89 b5 20 7f 03 c0    	mov    %esi,-0x3ffc80e0(%ebp)
      d->blocks_per_arena = (PGSIZE - sizeof (struct arena)) / block_size;
c0022e1f:	89 f8                	mov    %edi,%eax
c0022e21:	ba 00 00 00 00       	mov    $0x0,%edx
c0022e26:	f7 f6                	div    %esi
c0022e28:	89 85 24 7f 03 c0    	mov    %eax,-0x3ffc80dc(%ebp)
c0022e2e:	89 eb                	mov    %ebp,%ebx
      list_init (&d->free_list);
c0022e30:	83 ec 0c             	sub    $0xc,%esp
c0022e33:	8d 85 28 7f 03 c0    	lea    -0x3ffc80d8(%ebp),%eax
c0022e39:	50                   	push   %eax
c0022e3a:	e8 77 4a 00 00       	call   c00278b6 <list_init>
      lock_init (&d->lock);
c0022e3f:	81 c3 38 7f 03 c0    	add    $0xc0037f38,%ebx
c0022e45:	89 1c 24             	mov    %ebx,(%esp)
c0022e48:	e8 68 f6 ff ff       	call   c00224b5 <lock_init>
  for (block_size = 16; block_size < PGSIZE / 2; block_size *= 2)
c0022e4d:	8d 04 36             	lea    (%esi,%esi,1),%eax
c0022e50:	89 c6                	mov    %eax,%esi
c0022e52:	83 c4 10             	add    $0x10,%esp
c0022e55:	3d ff 07 00 00       	cmp    $0x7ff,%eax
c0022e5a:	76 a1                	jbe    c0022dfd <malloc_init+0x67>
}
c0022e5c:	83 c4 0c             	add    $0xc,%esp
c0022e5f:	5b                   	pop    %ebx
c0022e60:	5e                   	pop    %esi
c0022e61:	5f                   	pop    %edi
c0022e62:	5d                   	pop    %ebp
c0022e63:	c3                   	ret    
      ASSERT (desc_cnt <= sizeof descs / sizeof *descs);
c0022e64:	83 ec 0c             	sub    $0xc,%esp
c0022e67:	68 6c d8 02 c0       	push   $0xc002d86c
c0022e6c:	68 9f cd 02 c0       	push   $0xc002cd9f
c0022e71:	68 3c b9 02 c0       	push   $0xc002b93c
c0022e76:	6a 4f                	push   $0x4f
c0022e78:	68 a9 d7 02 c0       	push   $0xc002d7a9
c0022e7d:	e8 8d 49 00 00       	call   c002780f <debug_panic>

c0022e82 <malloc>:
{
c0022e82:	55                   	push   %ebp
c0022e83:	57                   	push   %edi
c0022e84:	56                   	push   %esi
c0022e85:	53                   	push   %ebx
c0022e86:	83 ec 1c             	sub    $0x1c,%esp
c0022e89:	8b 54 24 30          	mov    0x30(%esp),%edx
  if (size == 0)
c0022e8d:	85 d2                	test   %edx,%edx
c0022e8f:	0f 84 2c 01 00 00    	je     c0022fc1 <malloc+0x13f>
  for (d = descs; d < descs + desc_cnt; d++)
c0022e95:	8b 0d 00 7f 03 c0    	mov    0xc0037f00,%ecx
c0022e9b:	8d 04 09             	lea    (%ecx,%ecx,1),%eax
c0022e9e:	01 c8                	add    %ecx,%eax
c0022ea0:	c1 e0 04             	shl    $0x4,%eax
c0022ea3:	05 20 7f 03 c0       	add    $0xc0037f20,%eax
c0022ea8:	3d 20 7f 03 c0       	cmp    $0xc0037f20,%eax
c0022ead:	0f 86 bb 00 00 00    	jbe    c0022f6e <malloc+0xec>
    if (d->block_size >= size)
c0022eb3:	3b 15 20 7f 03 c0    	cmp    0xc0037f20,%edx
c0022eb9:	0f 86 10 01 00 00    	jbe    c0022fcf <malloc+0x14d>
c0022ebf:	bb 20 7f 03 c0       	mov    $0xc0037f20,%ebx
  for (d = descs; d < descs + desc_cnt; d++)
c0022ec4:	83 c3 30             	add    $0x30,%ebx
c0022ec7:	39 c3                	cmp    %eax,%ebx
c0022ec9:	0f 83 a4 00 00 00    	jae    c0022f73 <malloc+0xf1>
    if (d->block_size >= size)
c0022ecf:	3b 13                	cmp    (%ebx),%edx
c0022ed1:	77 f1                	ja     c0022ec4 <malloc+0x42>
  lock_acquire (&d->lock);
c0022ed3:	8d 43 18             	lea    0x18(%ebx),%eax
c0022ed6:	89 44 24 0c          	mov    %eax,0xc(%esp)
c0022eda:	83 ec 0c             	sub    $0xc,%esp
c0022edd:	50                   	push   %eax
c0022ede:	e8 54 f6 ff ff       	call   c0022537 <lock_acquire>
  if (list_empty (&d->free_list))
c0022ee3:	8d 7b 08             	lea    0x8(%ebx),%edi
c0022ee6:	89 3c 24             	mov    %edi,(%esp)
c0022ee9:	e8 0d 4f 00 00       	call   c0027dfb <list_empty>
c0022eee:	83 c4 10             	add    $0x10,%esp
c0022ef1:	84 c0                	test   %al,%al
c0022ef3:	74 4d                	je     c0022f42 <malloc+0xc0>
      a = palloc_get_page (0);
c0022ef5:	83 ec 0c             	sub    $0xc,%esp
c0022ef8:	6a 00                	push   $0x0
c0022efa:	e8 11 fc ff ff       	call   c0022b10 <palloc_get_page>
c0022eff:	89 c5                	mov    %eax,%ebp
      if (a == NULL) 
c0022f01:	83 c4 10             	add    $0x10,%esp
c0022f04:	85 c0                	test   %eax,%eax
c0022f06:	0f 84 9f 00 00 00    	je     c0022fab <malloc+0x129>
      a->magic = ARENA_MAGIC;
c0022f0c:	c7 00 ed 8e 54 9a    	movl   $0x9a548eed,(%eax)
      a->desc = d;
c0022f12:	89 58 04             	mov    %ebx,0x4(%eax)
      a->free_cnt = d->blocks_per_arena;
c0022f15:	8b 43 04             	mov    0x4(%ebx),%eax
c0022f18:	89 45 08             	mov    %eax,0x8(%ebp)
      for (i = 0; i < d->blocks_per_arena; i++) 
c0022f1b:	83 7b 04 00          	cmpl   $0x0,0x4(%ebx)
c0022f1f:	74 21                	je     c0022f42 <malloc+0xc0>
c0022f21:	be 00 00 00 00       	mov    $0x0,%esi
          struct block *b = arena_to_block (a, i);
c0022f26:	89 f2                	mov    %esi,%edx
c0022f28:	89 e8                	mov    %ebp,%eax
c0022f2a:	e8 1d fd ff ff       	call   c0022c4c <arena_to_block>
          list_push_back (&d->free_list, &b->free_elem);
c0022f2f:	83 ec 08             	sub    $0x8,%esp
c0022f32:	50                   	push   %eax
c0022f33:	57                   	push   %edi
c0022f34:	e8 1a 4e 00 00       	call   c0027d53 <list_push_back>
      for (i = 0; i < d->blocks_per_arena; i++) 
c0022f39:	46                   	inc    %esi
c0022f3a:	83 c4 10             	add    $0x10,%esp
c0022f3d:	39 73 04             	cmp    %esi,0x4(%ebx)
c0022f40:	77 e4                	ja     c0022f26 <malloc+0xa4>
  b = list_entry (list_pop_front (&d->free_list), struct block, free_elem);
c0022f42:	83 ec 0c             	sub    $0xc,%esp
c0022f45:	57                   	push   %edi
c0022f46:	e8 12 4f 00 00       	call   c0027e5d <list_pop_front>
c0022f4b:	89 c3                	mov    %eax,%ebx
  a = block_to_arena (b);
c0022f4d:	e8 7f fd ff ff       	call   c0022cd1 <block_to_arena>
  a->free_cnt--;
c0022f52:	ff 48 08             	decl   0x8(%eax)
  lock_release (&d->lock);
c0022f55:	83 c4 04             	add    $0x4,%esp
c0022f58:	ff 74 24 18          	pushl  0x18(%esp)
c0022f5c:	e8 fb f6 ff ff       	call   c002265c <lock_release>
  return b;
c0022f61:	83 c4 10             	add    $0x10,%esp
c0022f64:	89 d8                	mov    %ebx,%eax
}
c0022f66:	83 c4 1c             	add    $0x1c,%esp
c0022f69:	5b                   	pop    %ebx
c0022f6a:	5e                   	pop    %esi
c0022f6b:	5f                   	pop    %edi
c0022f6c:	5d                   	pop    %ebp
c0022f6d:	c3                   	ret    
  for (d = descs; d < descs + desc_cnt; d++)
c0022f6e:	bb 20 7f 03 c0       	mov    $0xc0037f20,%ebx
  if (d == descs + desc_cnt) 
c0022f73:	39 d8                	cmp    %ebx,%eax
c0022f75:	0f 85 58 ff ff ff    	jne    c0022ed3 <malloc+0x51>
      size_t page_cnt = DIV_ROUND_UP (size + sizeof *a, PGSIZE);
c0022f7b:	8d 9a 0b 10 00 00    	lea    0x100b(%edx),%ebx
c0022f81:	c1 eb 0c             	shr    $0xc,%ebx
      a = palloc_get_multiple (0, page_cnt);
c0022f84:	83 ec 08             	sub    $0x8,%esp
c0022f87:	53                   	push   %ebx
c0022f88:	6a 00                	push   $0x0
c0022f8a:	e8 ed fa ff ff       	call   c0022a7c <palloc_get_multiple>
      if (a == NULL)
c0022f8f:	83 c4 10             	add    $0x10,%esp
c0022f92:	85 c0                	test   %eax,%eax
c0022f94:	74 32                	je     c0022fc8 <malloc+0x146>
      a->magic = ARENA_MAGIC;
c0022f96:	c7 00 ed 8e 54 9a    	movl   $0x9a548eed,(%eax)
      a->desc = NULL;
c0022f9c:	c7 40 04 00 00 00 00 	movl   $0x0,0x4(%eax)
      a->free_cnt = page_cnt;
c0022fa3:	89 58 08             	mov    %ebx,0x8(%eax)
      return a + 1;
c0022fa6:	83 c0 0c             	add    $0xc,%eax
c0022fa9:	eb bb                	jmp    c0022f66 <malloc+0xe4>
          lock_release (&d->lock);
c0022fab:	83 ec 0c             	sub    $0xc,%esp
c0022fae:	ff 74 24 18          	pushl  0x18(%esp)
c0022fb2:	e8 a5 f6 ff ff       	call   c002265c <lock_release>
          return NULL; 
c0022fb7:	83 c4 10             	add    $0x10,%esp
c0022fba:	b8 00 00 00 00       	mov    $0x0,%eax
c0022fbf:	eb a5                	jmp    c0022f66 <malloc+0xe4>
    return NULL;
c0022fc1:	b8 00 00 00 00       	mov    $0x0,%eax
c0022fc6:	eb 9e                	jmp    c0022f66 <malloc+0xe4>
        return NULL;
c0022fc8:	b8 00 00 00 00       	mov    $0x0,%eax
c0022fcd:	eb 97                	jmp    c0022f66 <malloc+0xe4>
    if (d->block_size >= size)
c0022fcf:	bb 20 7f 03 c0       	mov    $0xc0037f20,%ebx
c0022fd4:	e9 fa fe ff ff       	jmp    c0022ed3 <malloc+0x51>

c0022fd9 <calloc>:
{
c0022fd9:	57                   	push   %edi
c0022fda:	53                   	push   %ebx
c0022fdb:	83 ec 04             	sub    $0x4,%esp
c0022fde:	8b 44 24 10          	mov    0x10(%esp),%eax
  size = a * b;
c0022fe2:	89 c3                	mov    %eax,%ebx
c0022fe4:	0f af 5c 24 14       	imul   0x14(%esp),%ebx
  if (size < a || size < b)
c0022fe9:	39 d8                	cmp    %ebx,%eax
c0022feb:	77 28                	ja     c0023015 <calloc+0x3c>
c0022fed:	39 5c 24 14          	cmp    %ebx,0x14(%esp)
c0022ff1:	77 29                	ja     c002301c <calloc+0x43>
  p = malloc (size);
c0022ff3:	83 ec 0c             	sub    $0xc,%esp
c0022ff6:	53                   	push   %ebx
c0022ff7:	e8 86 fe ff ff       	call   c0022e82 <malloc>
c0022ffc:	89 c2                	mov    %eax,%edx
  if (p != NULL)
c0022ffe:	83 c4 10             	add    $0x10,%esp
c0023001:	85 c0                	test   %eax,%eax
c0023003:	74 08                	je     c002300d <calloc+0x34>
    memset (p, 0, size);
c0023005:	b0 00                	mov    $0x0,%al
c0023007:	89 d7                	mov    %edx,%edi
c0023009:	89 d9                	mov    %ebx,%ecx
c002300b:	f3 aa                	rep stos %al,%es:(%edi)
}
c002300d:	89 d0                	mov    %edx,%eax
c002300f:	83 c4 04             	add    $0x4,%esp
c0023012:	5b                   	pop    %ebx
c0023013:	5f                   	pop    %edi
c0023014:	c3                   	ret    
    return NULL;
c0023015:	ba 00 00 00 00       	mov    $0x0,%edx
c002301a:	eb f1                	jmp    c002300d <calloc+0x34>
c002301c:	ba 00 00 00 00       	mov    $0x0,%edx
c0023021:	eb ea                	jmp    c002300d <calloc+0x34>

c0023023 <free>:
{
c0023023:	55                   	push   %ebp
c0023024:	57                   	push   %edi
c0023025:	56                   	push   %esi
c0023026:	53                   	push   %ebx
c0023027:	83 ec 0c             	sub    $0xc,%esp
c002302a:	8b 6c 24 20          	mov    0x20(%esp),%ebp
  if (p != NULL)
c002302e:	85 ed                	test   %ebp,%ebp
c0023030:	0f 84 86 00 00 00    	je     c00230bc <free+0x99>
      struct arena *a = block_to_arena (b);
c0023036:	89 e8                	mov    %ebp,%eax
c0023038:	e8 94 fc ff ff       	call   c0022cd1 <block_to_arena>
c002303d:	89 c6                	mov    %eax,%esi
      struct desc *d = a->desc;
c002303f:	8b 58 04             	mov    0x4(%eax),%ebx
      if (d != NULL) 
c0023042:	85 db                	test   %ebx,%ebx
c0023044:	0f 84 9b 00 00 00    	je     c00230e5 <free+0xc2>
          memset (b, 0xcc, d->block_size);
c002304a:	8b 0b                	mov    (%ebx),%ecx
c002304c:	b0 cc                	mov    $0xcc,%al
c002304e:	89 ef                	mov    %ebp,%edi
c0023050:	f3 aa                	rep stos %al,%es:(%edi)
          lock_acquire (&d->lock);
c0023052:	8d 7b 18             	lea    0x18(%ebx),%edi
c0023055:	83 ec 0c             	sub    $0xc,%esp
c0023058:	57                   	push   %edi
c0023059:	e8 d9 f4 ff ff       	call   c0022537 <lock_acquire>
          list_push_front (&d->free_list, &b->free_elem);
c002305e:	83 c4 08             	add    $0x8,%esp
c0023061:	55                   	push   %ebp
c0023062:	8d 43 08             	lea    0x8(%ebx),%eax
c0023065:	50                   	push   %eax
c0023066:	e8 cb 4c 00 00       	call   c0027d36 <list_push_front>
          if (++a->free_cnt >= d->blocks_per_arena) 
c002306b:	8b 46 08             	mov    0x8(%esi),%eax
c002306e:	40                   	inc    %eax
c002306f:	89 46 08             	mov    %eax,0x8(%esi)
c0023072:	8b 53 04             	mov    0x4(%ebx),%edx
c0023075:	83 c4 10             	add    $0x10,%esp
c0023078:	39 d0                	cmp    %edx,%eax
c002307a:	72 34                	jb     c00230b0 <free+0x8d>
              ASSERT (a->free_cnt == d->blocks_per_arena);
c002307c:	39 d0                	cmp    %edx,%eax
c002307e:	75 44                	jne    c00230c4 <free+0xa1>
              for (i = 0; i < d->blocks_per_arena; i++) 
c0023080:	bd 00 00 00 00       	mov    $0x0,%ebp
c0023085:	85 c0                	test   %eax,%eax
c0023087:	74 1b                	je     c00230a4 <free+0x81>
                  struct block *b = arena_to_block (a, i);
c0023089:	89 ea                	mov    %ebp,%edx
c002308b:	89 f0                	mov    %esi,%eax
c002308d:	e8 ba fb ff ff       	call   c0022c4c <arena_to_block>
                  list_remove (&b->free_elem);
c0023092:	83 ec 0c             	sub    $0xc,%esp
c0023095:	50                   	push   %eax
c0023096:	e8 d5 4c 00 00       	call   c0027d70 <list_remove>
              for (i = 0; i < d->blocks_per_arena; i++) 
c002309b:	45                   	inc    %ebp
c002309c:	83 c4 10             	add    $0x10,%esp
c002309f:	39 6b 04             	cmp    %ebp,0x4(%ebx)
c00230a2:	77 e5                	ja     c0023089 <free+0x66>
              palloc_free_page (a);
c00230a4:	83 ec 0c             	sub    $0xc,%esp
c00230a7:	56                   	push   %esi
c00230a8:	e8 8d fb ff ff       	call   c0022c3a <palloc_free_page>
c00230ad:	83 c4 10             	add    $0x10,%esp
          lock_release (&d->lock);
c00230b0:	83 ec 0c             	sub    $0xc,%esp
c00230b3:	57                   	push   %edi
c00230b4:	e8 a3 f5 ff ff       	call   c002265c <lock_release>
c00230b9:	83 c4 10             	add    $0x10,%esp
}
c00230bc:	83 c4 0c             	add    $0xc,%esp
c00230bf:	5b                   	pop    %ebx
c00230c0:	5e                   	pop    %esi
c00230c1:	5f                   	pop    %edi
c00230c2:	5d                   	pop    %ebp
c00230c3:	c3                   	ret    
              ASSERT (a->free_cnt == d->blocks_per_arena);
c00230c4:	83 ec 0c             	sub    $0xc,%esp
c00230c7:	68 98 d8 02 c0       	push   $0xc002d898
c00230cc:	68 9f cd 02 c0       	push   $0xc002cd9f
c00230d1:	68 14 b9 02 c0       	push   $0xc002b914
c00230d6:	68 f6 00 00 00       	push   $0xf6
c00230db:	68 a9 d7 02 c0       	push   $0xc002d7a9
c00230e0:	e8 2a 47 00 00       	call   c002780f <debug_panic>
          palloc_free_multiple (a, a->free_cnt);
c00230e5:	83 ec 08             	sub    $0x8,%esp
c00230e8:	ff 70 08             	pushl  0x8(%eax)
c00230eb:	50                   	push   %eax
c00230ec:	e8 31 fa ff ff       	call   c0022b22 <palloc_free_multiple>
          return;
c00230f1:	83 c4 10             	add    $0x10,%esp
c00230f4:	eb c6                	jmp    c00230bc <free+0x99>

c00230f6 <realloc>:
{
c00230f6:	55                   	push   %ebp
c00230f7:	57                   	push   %edi
c00230f8:	56                   	push   %esi
c00230f9:	53                   	push   %ebx
c00230fa:	83 ec 0c             	sub    $0xc,%esp
c00230fd:	8b 5c 24 20          	mov    0x20(%esp),%ebx
c0023101:	8b 74 24 24          	mov    0x24(%esp),%esi
  if (new_size == 0) 
c0023105:	85 f6                	test   %esi,%esi
c0023107:	74 4a                	je     c0023153 <realloc+0x5d>
      void *new_block = malloc (new_size);
c0023109:	83 ec 0c             	sub    $0xc,%esp
c002310c:	56                   	push   %esi
c002310d:	e8 70 fd ff ff       	call   c0022e82 <malloc>
c0023112:	89 c5                	mov    %eax,%ebp
      if (old_block != NULL && new_block != NULL)
c0023114:	83 c4 10             	add    $0x10,%esp
c0023117:	85 db                	test   %ebx,%ebx
c0023119:	74 2e                	je     c0023149 <realloc+0x53>
c002311b:	85 c0                	test   %eax,%eax
c002311d:	74 2a                	je     c0023149 <realloc+0x53>
  struct arena *a = block_to_arena (b);
c002311f:	89 d8                	mov    %ebx,%eax
c0023121:	e8 ab fb ff ff       	call   c0022cd1 <block_to_arena>
  struct desc *d = a->desc;
c0023126:	8b 50 04             	mov    0x4(%eax),%edx
  return d != NULL ? d->block_size : PGSIZE * a->free_cnt - pg_ofs (block);
c0023129:	85 d2                	test   %edx,%edx
c002312b:	74 39                	je     c0023166 <realloc+0x70>
c002312d:	8b 02                	mov    (%edx),%eax
          size_t min_size = new_size < old_size ? new_size : old_size;
c002312f:	89 f1                	mov    %esi,%ecx
c0023131:	39 c6                	cmp    %eax,%esi
c0023133:	76 02                	jbe    c0023137 <realloc+0x41>
c0023135:	89 c1                	mov    %eax,%ecx
          memcpy (new_block, old_block, min_size);
c0023137:	89 ef                	mov    %ebp,%edi
c0023139:	89 de                	mov    %ebx,%esi
c002313b:	f3 a4                	rep movsb %ds:(%esi),%es:(%edi)
          free (old_block);
c002313d:	83 ec 0c             	sub    $0xc,%esp
c0023140:	53                   	push   %ebx
c0023141:	e8 dd fe ff ff       	call   c0023023 <free>
c0023146:	83 c4 10             	add    $0x10,%esp
}
c0023149:	89 e8                	mov    %ebp,%eax
c002314b:	83 c4 0c             	add    $0xc,%esp
c002314e:	5b                   	pop    %ebx
c002314f:	5e                   	pop    %esi
c0023150:	5f                   	pop    %edi
c0023151:	5d                   	pop    %ebp
c0023152:	c3                   	ret    
      free (old_block);
c0023153:	83 ec 0c             	sub    $0xc,%esp
c0023156:	53                   	push   %ebx
c0023157:	e8 c7 fe ff ff       	call   c0023023 <free>
      return NULL;
c002315c:	83 c4 10             	add    $0x10,%esp
c002315f:	bd 00 00 00 00       	mov    $0x0,%ebp
c0023164:	eb e3                	jmp    c0023149 <realloc+0x53>
  return d != NULL ? d->block_size : PGSIZE * a->free_cnt - pg_ofs (block);
c0023166:	8b 40 08             	mov    0x8(%eax),%eax
c0023169:	c1 e0 0c             	shl    $0xc,%eax
c002316c:	89 da                	mov    %ebx,%edx
c002316e:	81 e2 ff 0f 00 00    	and    $0xfff,%edx
c0023174:	29 d0                	sub    %edx,%eax
c0023176:	eb b7                	jmp    c002312f <realloc+0x39>

c0023178 <pit_configure_channel>:
     - Other modes are less useful.

   FREQUENCY is the number of periods per second, in Hz. */
void
pit_configure_channel (int channel, int mode, int frequency)
{
c0023178:	57                   	push   %edi
c0023179:	56                   	push   %esi
c002317a:	53                   	push   %ebx
c002317b:	8b 74 24 10          	mov    0x10(%esp),%esi
c002317f:	8b 5c 24 14          	mov    0x14(%esp),%ebx
c0023183:	8b 4c 24 18          	mov    0x18(%esp),%ecx
  uint16_t count;
  enum intr_level old_level;

  ASSERT (channel == 0 || channel == 2);
c0023187:	f7 c6 fd ff ff ff    	test   $0xfffffffd,%esi
c002318d:	74 1e                	je     c00231ad <pit_configure_channel+0x35>
c002318f:	83 ec 0c             	sub    $0xc,%esp
c0023192:	68 bb d8 02 c0       	push   $0xc002d8bb
c0023197:	68 9f cd 02 c0       	push   $0xc002cd9f
c002319c:	68 48 b9 02 c0       	push   $0xc002b948
c00231a1:	6a 33                	push   $0x33
c00231a3:	68 d8 d8 02 c0       	push   $0xc002d8d8
c00231a8:	e8 62 46 00 00       	call   c002780f <debug_panic>
  ASSERT (mode == 2 || mode == 3);
c00231ad:	8d 43 fe             	lea    -0x2(%ebx),%eax
c00231b0:	83 f8 01             	cmp    $0x1,%eax
c00231b3:	77 22                	ja     c00231d7 <pit_configure_channel+0x5f>

  /* Convert FREQUENCY to a PIT counter value.  The PIT has a
     clock that runs at PIT_HZ cycles per second.  We must
     translate FREQUENCY into a number of these cycles. */
  if (frequency < 19)
c00231b5:	83 f9 12             	cmp    $0x12,%ecx
c00231b8:	7e 3b                	jle    c00231f5 <pit_configure_channel+0x7d>
         16-bit counter.  Force it to 0, which the PIT treats as
         65536, the highest possible count.  This yields a 18.2
         Hz timer, approximately. */
      count = 0;
    }
  else if (frequency > PIT_HZ)
c00231ba:	81 f9 dc 34 12 00    	cmp    $0x1234dc,%ecx
c00231c0:	7f 6b                	jg     c002322d <pit_configure_channel+0xb5>
         a 596.590 kHz timer, approximately.  (This timer rate is
         probably too fast to be useful anyhow.) */
      count = 2;
    }
  else
    count = (PIT_HZ + frequency / 2) / frequency;
c00231c2:	89 c8                	mov    %ecx,%eax
c00231c4:	c1 e8 1f             	shr    $0x1f,%eax
c00231c7:	01 c8                	add    %ecx,%eax
c00231c9:	d1 f8                	sar    %eax
c00231cb:	05 dc 34 12 00       	add    $0x1234dc,%eax
c00231d0:	99                   	cltd   
c00231d1:	f7 f9                	idiv   %ecx
c00231d3:	89 c7                	mov    %eax,%edi
c00231d5:	eb 23                	jmp    c00231fa <pit_configure_channel+0x82>
  ASSERT (mode == 2 || mode == 3);
c00231d7:	83 ec 0c             	sub    $0xc,%esp
c00231da:	68 ec d8 02 c0       	push   $0xc002d8ec
c00231df:	68 9f cd 02 c0       	push   $0xc002cd9f
c00231e4:	68 48 b9 02 c0       	push   $0xc002b948
c00231e9:	6a 34                	push   $0x34
c00231eb:	68 d8 d8 02 c0       	push   $0xc002d8d8
c00231f0:	e8 1a 46 00 00       	call   c002780f <debug_panic>
      count = 0;
c00231f5:	bf 00 00 00 00       	mov    $0x0,%edi

  /* Configure the PIT mode and load its counters. */
  old_level = intr_disable ();
c00231fa:	e8 55 e0 ff ff       	call   c0021254 <intr_disable>
c00231ff:	89 c1                	mov    %eax,%ecx
  outb (PIT_PORT_CONTROL, (channel << 6) | 0x30 | (mode << 1));
c0023201:	8d 04 1b             	lea    (%ebx,%ebx,1),%eax
c0023204:	83 c8 30             	or     $0x30,%eax
c0023207:	89 f3                	mov    %esi,%ebx
c0023209:	c1 e3 06             	shl    $0x6,%ebx
c002320c:	09 d8                	or     %ebx,%eax
c002320e:	e6 43                	out    %al,$0x43
  outb (PIT_PORT_COUNTER (channel), count);
c0023210:	8d 56 40             	lea    0x40(%esi),%edx
c0023213:	89 f8                	mov    %edi,%eax
c0023215:	ee                   	out    %al,(%dx)
  outb (PIT_PORT_COUNTER (channel), count >> 8);
c0023216:	89 f8                	mov    %edi,%eax
c0023218:	66 c1 e8 08          	shr    $0x8,%ax
c002321c:	ee                   	out    %al,(%dx)
  intr_set_level (old_level);
c002321d:	83 ec 0c             	sub    $0xc,%esp
c0023220:	51                   	push   %ecx
c0023221:	e8 35 e0 ff ff       	call   c002125b <intr_set_level>
}
c0023226:	83 c4 10             	add    $0x10,%esp
c0023229:	5b                   	pop    %ebx
c002322a:	5e                   	pop    %esi
c002322b:	5f                   	pop    %edi
c002322c:	c3                   	ret    
      count = 2;
c002322d:	bf 02 00 00 00       	mov    $0x2,%edi
c0023232:	eb c6                	jmp    c00231fa <pit_configure_channel+0x82>

c0023234 <busy_wait>:
   affect timings, so that if this function was inlined
   differently in different places the results would be difficult
   to predict. */
static void NO_INLINE
busy_wait (int64_t loops) 
{
c0023234:	53                   	push   %ebx
  while (loops-- > 0)
c0023235:	89 c1                	mov    %eax,%ecx
c0023237:	89 d3                	mov    %edx,%ebx
c0023239:	83 c1 ff             	add    $0xffffffff,%ecx
c002323c:	83 d3 ff             	adc    $0xffffffff,%ebx
c002323f:	85 d2                	test   %edx,%edx
c0023241:	78 13                	js     c0023256 <busy_wait+0x22>
c0023243:	85 d2                	test   %edx,%edx
c0023245:	7e 11                	jle    c0023258 <busy_wait+0x24>
c0023247:	83 c1 ff             	add    $0xffffffff,%ecx
c002324a:	83 d3 ff             	adc    $0xffffffff,%ebx
c002324d:	89 d8                	mov    %ebx,%eax
c002324f:	21 c8                	and    %ecx,%eax
c0023251:	83 f8 ff             	cmp    $0xffffffff,%eax
c0023254:	75 f1                	jne    c0023247 <busy_wait+0x13>
    barrier ();
}
c0023256:	5b                   	pop    %ebx
c0023257:	c3                   	ret    
  while (loops-- > 0)
c0023258:	83 f8 00             	cmp    $0x0,%eax
c002325b:	76 f9                	jbe    c0023256 <busy_wait+0x22>
c002325d:	eb e8                	jmp    c0023247 <busy_wait+0x13>

c002325f <too_many_loops>:
{
c002325f:	55                   	push   %ebp
c0023260:	57                   	push   %edi
c0023261:	56                   	push   %esi
c0023262:	53                   	push   %ebx
c0023263:	83 ec 04             	sub    $0x4,%esp
  int64_t start = ticks;
c0023266:	8b 2d 08 81 03 c0    	mov    0xc0038108,%ebp
c002326c:	8b 3d 0c 81 03 c0    	mov    0xc003810c,%edi
  while (ticks == start)
c0023272:	8b 35 08 81 03 c0    	mov    0xc0038108,%esi
c0023278:	8b 1d 0c 81 03 c0    	mov    0xc003810c,%ebx
c002327e:	89 ea                	mov    %ebp,%edx
c0023280:	31 f2                	xor    %esi,%edx
c0023282:	89 f9                	mov    %edi,%ecx
c0023284:	31 d9                	xor    %ebx,%ecx
c0023286:	09 d1                	or     %edx,%ecx
c0023288:	74 e8                	je     c0023272 <too_many_loops+0x13>
  busy_wait (loops);
c002328a:	ba 00 00 00 00       	mov    $0x0,%edx
c002328f:	e8 a0 ff ff ff       	call   c0023234 <busy_wait>
  return start != ticks;
c0023294:	33 35 08 81 03 c0    	xor    0xc0038108,%esi
c002329a:	33 1d 0c 81 03 c0    	xor    0xc003810c,%ebx
c00232a0:	09 de                	or     %ebx,%esi
c00232a2:	0f 95 c0             	setne  %al
}
c00232a5:	83 c4 04             	add    $0x4,%esp
c00232a8:	5b                   	pop    %ebx
c00232a9:	5e                   	pop    %esi
c00232aa:	5f                   	pop    %edi
c00232ab:	5d                   	pop    %ebp
c00232ac:	c3                   	ret    

c00232ad <timer_interrupt>:
{
c00232ad:	83 ec 0c             	sub    $0xc,%esp
  ticks++;
c00232b0:	83 05 08 81 03 c0 01 	addl   $0x1,0xc0038108
c00232b7:	83 15 0c 81 03 c0 00 	adcl   $0x0,0xc003810c
  thread_tick ();
c00232be:	e8 ed d8 ff ff       	call   c0020bb0 <thread_tick>
  sleep_to_ready(ticks);
c00232c3:	83 ec 08             	sub    $0x8,%esp
c00232c6:	ff 35 0c 81 03 c0    	pushl  0xc003810c
c00232cc:	ff 35 08 81 03 c0    	pushl  0xc0038108
c00232d2:	e8 3f d9 ff ff       	call   c0020c16 <sleep_to_ready>
}
c00232d7:	83 c4 1c             	add    $0x1c,%esp
c00232da:	c3                   	ret    

c00232db <real_time_delay>:
}

/* Busy-wait for approximately NUM/DENOM seconds. */
static void
real_time_delay (int64_t num, int32_t denom)
{
c00232db:	57                   	push   %edi
c00232dc:	56                   	push   %esi
c00232dd:	53                   	push   %ebx
c00232de:	89 c6                	mov    %eax,%esi
c00232e0:	89 d7                	mov    %edx,%edi
c00232e2:	89 cb                	mov    %ecx,%ebx
  /* Scale the numerator and denominator down by 1000 to avoid
     the possibility of overflow. */
  ASSERT (denom % 1000 == 0);
c00232e4:	b9 e8 03 00 00       	mov    $0x3e8,%ecx
c00232e9:	89 d8                	mov    %ebx,%eax
c00232eb:	99                   	cltd   
c00232ec:	f7 f9                	idiv   %ecx
c00232ee:	85 d2                	test   %edx,%edx
c00232f0:	75 5c                	jne    c002334e <real_time_delay+0x73>
  busy_wait (loops_per_tick * num / 1000 * TIMER_FREQ / (denom / 1000)); 
c00232f2:	a1 00 81 03 c0       	mov    0xc0038100,%eax
c00232f7:	0f af f8             	imul   %eax,%edi
c00232fa:	f7 e6                	mul    %esi
c00232fc:	01 fa                	add    %edi,%edx
c00232fe:	6a 00                	push   $0x0
c0023300:	68 e8 03 00 00       	push   $0x3e8
c0023305:	52                   	push   %edx
c0023306:	50                   	push   %eax
c0023307:	e8 1d 3f 00 00       	call   c0027229 <__divdi3>
c002330c:	83 c4 10             	add    $0x10,%esp
c002330f:	89 c6                	mov    %eax,%esi
c0023311:	6b ca 64             	imul   $0x64,%edx,%ecx
c0023314:	bf 64 00 00 00       	mov    $0x64,%edi
c0023319:	89 f8                	mov    %edi,%eax
c002331b:	f7 e6                	mul    %esi
c002331d:	89 c6                	mov    %eax,%esi
c002331f:	89 d7                	mov    %edx,%edi
c0023321:	01 cf                	add    %ecx,%edi
c0023323:	b9 d3 4d 62 10       	mov    $0x10624dd3,%ecx
c0023328:	89 c8                	mov    %ecx,%eax
c002332a:	f7 eb                	imul   %ebx
c002332c:	89 d1                	mov    %edx,%ecx
c002332e:	89 c8                	mov    %ecx,%eax
c0023330:	c1 f8 06             	sar    $0x6,%eax
c0023333:	c1 fb 1f             	sar    $0x1f,%ebx
c0023336:	29 d8                	sub    %ebx,%eax
c0023338:	99                   	cltd   
c0023339:	52                   	push   %edx
c002333a:	50                   	push   %eax
c002333b:	57                   	push   %edi
c002333c:	56                   	push   %esi
c002333d:	e8 e7 3e 00 00       	call   c0027229 <__divdi3>
c0023342:	83 c4 10             	add    $0x10,%esp
c0023345:	e8 ea fe ff ff       	call   c0023234 <busy_wait>
}
c002334a:	5b                   	pop    %ebx
c002334b:	5e                   	pop    %esi
c002334c:	5f                   	pop    %edi
c002334d:	c3                   	ret    
  ASSERT (denom % 1000 == 0);
c002334e:	83 ec 0c             	sub    $0xc,%esp
c0023351:	68 03 d9 02 c0       	push   $0xc002d903
c0023356:	68 9f cd 02 c0       	push   $0xc002cd9f
c002335b:	68 60 b9 02 c0       	push   $0xc002b960
c0023360:	68 f7 00 00 00       	push   $0xf7
c0023365:	68 15 d9 02 c0       	push   $0xc002d915
c002336a:	e8 a0 44 00 00       	call   c002780f <debug_panic>

c002336f <timer_init>:
{
c002336f:	83 ec 10             	sub    $0x10,%esp
  pit_configure_channel (0, 2, TIMER_FREQ);
c0023372:	6a 64                	push   $0x64
c0023374:	6a 02                	push   $0x2
c0023376:	6a 00                	push   $0x0
c0023378:	e8 fb fd ff ff       	call   c0023178 <pit_configure_channel>
  intr_register_ext (0x20, timer_interrupt, "8254 Timer");
c002337d:	83 c4 0c             	add    $0xc,%esp
c0023380:	68 2b d9 02 c0       	push   $0xc002d92b
c0023385:	68 ad 32 02 c0       	push   $0xc00232ad
c002338a:	6a 20                	push   $0x20
c002338c:	e8 44 e0 ff ff       	call   c00213d5 <intr_register_ext>
}
c0023391:	83 c4 1c             	add    $0x1c,%esp
c0023394:	c3                   	ret    

c0023395 <timer_calibrate>:
{
c0023395:	57                   	push   %edi
c0023396:	56                   	push   %esi
c0023397:	53                   	push   %ebx
  ASSERT (intr_get_level () == INTR_ON);
c0023398:	e8 7a de ff ff       	call   c0021217 <intr_get_level>
c002339d:	83 f8 01             	cmp    $0x1,%eax
c00233a0:	75 56                	jne    c00233f8 <timer_calibrate+0x63>
  printf ("Calibrating timer...  ");
c00233a2:	83 ec 0c             	sub    $0xc,%esp
c00233a5:	68 53 d9 02 c0       	push   $0xc002d953
c00233aa:	e8 b2 29 00 00       	call   c0025d61 <printf>
  loops_per_tick = 1u << 10;
c00233af:	c7 05 00 81 03 c0 00 	movl   $0x400,0xc0038100
c00233b6:	04 00 00 
  while (!too_many_loops (loops_per_tick << 1)) 
c00233b9:	83 c4 10             	add    $0x10,%esp
c00233bc:	8b 35 00 81 03 c0    	mov    0xc0038100,%esi
c00233c2:	8d 1c 36             	lea    (%esi,%esi,1),%ebx
c00233c5:	89 d8                	mov    %ebx,%eax
c00233c7:	e8 93 fe ff ff       	call   c002325f <too_many_loops>
c00233cc:	84 c0                	test   %al,%al
c00233ce:	75 46                	jne    c0023416 <timer_calibrate+0x81>
      loops_per_tick <<= 1;
c00233d0:	89 1d 00 81 03 c0    	mov    %ebx,0xc0038100
      ASSERT (loops_per_tick != 0);
c00233d6:	85 db                	test   %ebx,%ebx
c00233d8:	75 e2                	jne    c00233bc <timer_calibrate+0x27>
c00233da:	83 ec 0c             	sub    $0xc,%esp
c00233dd:	68 6a d9 02 c0       	push   $0xc002d96a
c00233e2:	68 9f cd 02 c0       	push   $0xc002cd9f
c00233e7:	68 8c b9 02 c0       	push   $0xc002b98c
c00233ec:	6a 39                	push   $0x39
c00233ee:	68 15 d9 02 c0       	push   $0xc002d915
c00233f3:	e8 17 44 00 00       	call   c002780f <debug_panic>
  ASSERT (intr_get_level () == INTR_ON);
c00233f8:	83 ec 0c             	sub    $0xc,%esp
c00233fb:	68 36 d9 02 c0       	push   $0xc002d936
c0023400:	68 9f cd 02 c0       	push   $0xc002cd9f
c0023405:	68 8c b9 02 c0       	push   $0xc002b98c
c002340a:	6a 30                	push   $0x30
c002340c:	68 15 d9 02 c0       	push   $0xc002d915
c0023411:	e8 f9 43 00 00       	call   c002780f <debug_panic>
  for (test_bit = high_bit >> 1; test_bit != high_bit >> 10; test_bit >>= 1)
c0023416:	89 f3                	mov    %esi,%ebx
c0023418:	d1 eb                	shr    %ebx
c002341a:	89 f7                	mov    %esi,%edi
c002341c:	c1 ef 0a             	shr    $0xa,%edi
c002341f:	39 df                	cmp    %ebx,%edi
c0023421:	75 27                	jne    c002344a <timer_calibrate+0xb5>
  printf ("%'"PRIu64" loops/s.\n", (uint64_t) loops_per_tick * TIMER_FREQ);
c0023423:	83 ec 04             	sub    $0x4,%esp
c0023426:	b8 64 00 00 00       	mov    $0x64,%eax
c002342b:	f7 25 00 81 03 c0    	mull   0xc0038100
c0023431:	52                   	push   %edx
c0023432:	50                   	push   %eax
c0023433:	68 7e d9 02 c0       	push   $0xc002d97e
c0023438:	e8 24 29 00 00       	call   c0025d61 <printf>
}
c002343d:	83 c4 10             	add    $0x10,%esp
c0023440:	5b                   	pop    %ebx
c0023441:	5e                   	pop    %esi
c0023442:	5f                   	pop    %edi
c0023443:	c3                   	ret    
  for (test_bit = high_bit >> 1; test_bit != high_bit >> 10; test_bit >>= 1)
c0023444:	d1 eb                	shr    %ebx
c0023446:	39 df                	cmp    %ebx,%edi
c0023448:	74 d9                	je     c0023423 <timer_calibrate+0x8e>
    if (!too_many_loops (high_bit | test_bit))
c002344a:	89 f0                	mov    %esi,%eax
c002344c:	09 d8                	or     %ebx,%eax
c002344e:	e8 0c fe ff ff       	call   c002325f <too_many_loops>
c0023453:	84 c0                	test   %al,%al
c0023455:	75 ed                	jne    c0023444 <timer_calibrate+0xaf>
      loops_per_tick |= test_bit;
c0023457:	09 1d 00 81 03 c0    	or     %ebx,0xc0038100
c002345d:	eb e5                	jmp    c0023444 <timer_calibrate+0xaf>

c002345f <timer_ticks>:
{
c002345f:	57                   	push   %edi
c0023460:	56                   	push   %esi
c0023461:	83 ec 04             	sub    $0x4,%esp
  enum intr_level old_level = intr_disable ();
c0023464:	e8 eb dd ff ff       	call   c0021254 <intr_disable>
  int64_t t = ticks;
c0023469:	8b 35 08 81 03 c0    	mov    0xc0038108,%esi
c002346f:	8b 3d 0c 81 03 c0    	mov    0xc003810c,%edi
  intr_set_level (old_level);
c0023475:	83 ec 0c             	sub    $0xc,%esp
c0023478:	50                   	push   %eax
c0023479:	e8 dd dd ff ff       	call   c002125b <intr_set_level>
}
c002347e:	89 f0                	mov    %esi,%eax
c0023480:	89 fa                	mov    %edi,%edx
c0023482:	83 c4 14             	add    $0x14,%esp
c0023485:	5e                   	pop    %esi
c0023486:	5f                   	pop    %edi
c0023487:	c3                   	ret    

c0023488 <timer_elapsed>:
{
c0023488:	57                   	push   %edi
c0023489:	56                   	push   %esi
c002348a:	83 ec 04             	sub    $0x4,%esp
c002348d:	8b 74 24 10          	mov    0x10(%esp),%esi
c0023491:	8b 7c 24 14          	mov    0x14(%esp),%edi
  return timer_ticks () - then;
c0023495:	e8 c5 ff ff ff       	call   c002345f <timer_ticks>
c002349a:	29 f0                	sub    %esi,%eax
c002349c:	19 fa                	sbb    %edi,%edx
}
c002349e:	83 c4 04             	add    $0x4,%esp
c00234a1:	5e                   	pop    %esi
c00234a2:	5f                   	pop    %edi
c00234a3:	c3                   	ret    

c00234a4 <timer_sleep>:
{
c00234a4:	57                   	push   %edi
c00234a5:	56                   	push   %esi
c00234a6:	83 ec 04             	sub    $0x4,%esp
c00234a9:	8b 74 24 10          	mov    0x10(%esp),%esi
c00234ad:	8b 7c 24 14          	mov    0x14(%esp),%edi
  int64_t start = timer_ticks ();
c00234b1:	e8 a9 ff ff ff       	call   c002345f <timer_ticks>
  ASSERT (intr_get_level () == INTR_ON);
c00234b6:	e8 5c dd ff ff       	call   c0021217 <intr_get_level>
c00234bb:	83 f8 01             	cmp    $0x1,%eax
c00234be:	75 10                	jne    c00234d0 <timer_sleep+0x2c>
  thread_sleep(ticks);
c00234c0:	83 ec 08             	sub    $0x8,%esp
c00234c3:	57                   	push   %edi
c00234c4:	56                   	push   %esi
c00234c5:	e8 ae db ff ff       	call   c0021078 <thread_sleep>
}
c00234ca:	83 c4 14             	add    $0x14,%esp
c00234cd:	5e                   	pop    %esi
c00234ce:	5f                   	pop    %edi
c00234cf:	c3                   	ret    
  ASSERT (intr_get_level () == INTR_ON);
c00234d0:	83 ec 0c             	sub    $0xc,%esp
c00234d3:	68 36 d9 02 c0       	push   $0xc002d936
c00234d8:	68 9f cd 02 c0       	push   $0xc002cd9f
c00234dd:	68 80 b9 02 c0       	push   $0xc002b980
c00234e2:	6a 5e                	push   $0x5e
c00234e4:	68 15 d9 02 c0       	push   $0xc002d915
c00234e9:	e8 21 43 00 00       	call   c002780f <debug_panic>

c00234ee <real_time_sleep>:
{
c00234ee:	55                   	push   %ebp
c00234ef:	57                   	push   %edi
c00234f0:	56                   	push   %esi
c00234f1:	53                   	push   %ebx
c00234f2:	83 ec 1c             	sub    $0x1c,%esp
c00234f5:	89 c6                	mov    %eax,%esi
c00234f7:	89 44 24 08          	mov    %eax,0x8(%esp)
c00234fb:	89 54 24 0c          	mov    %edx,0xc(%esp)
c00234ff:	89 cd                	mov    %ecx,%ebp
  int64_t ticks = num * TIMER_FREQ / denom;
c0023501:	6b fa 64             	imul   $0x64,%edx,%edi
c0023504:	b9 64 00 00 00       	mov    $0x64,%ecx
c0023509:	89 c8                	mov    %ecx,%eax
c002350b:	f7 e6                	mul    %esi
c002350d:	89 c1                	mov    %eax,%ecx
c002350f:	89 d3                	mov    %edx,%ebx
c0023511:	01 fb                	add    %edi,%ebx
c0023513:	89 e8                	mov    %ebp,%eax
c0023515:	99                   	cltd   
c0023516:	52                   	push   %edx
c0023517:	55                   	push   %ebp
c0023518:	53                   	push   %ebx
c0023519:	51                   	push   %ecx
c002351a:	e8 0a 3d 00 00       	call   c0027229 <__divdi3>
c002351f:	83 c4 10             	add    $0x10,%esp
c0023522:	89 c6                	mov    %eax,%esi
c0023524:	89 d7                	mov    %edx,%edi
  ASSERT (intr_get_level () == INTR_ON);
c0023526:	e8 ec dc ff ff       	call   c0021217 <intr_get_level>
c002352b:	83 f8 01             	cmp    $0x1,%eax
c002352e:	75 1d                	jne    c002354d <real_time_sleep+0x5f>
  if (ticks > 0)
c0023530:	85 ff                	test   %edi,%edi
c0023532:	78 3f                	js     c0023573 <real_time_sleep+0x85>
c0023534:	85 ff                	test   %edi,%edi
c0023536:	7e 36                	jle    c002356e <real_time_sleep+0x80>
      timer_sleep (ticks); 
c0023538:	83 ec 08             	sub    $0x8,%esp
c002353b:	57                   	push   %edi
c002353c:	56                   	push   %esi
c002353d:	e8 62 ff ff ff       	call   c00234a4 <timer_sleep>
c0023542:	83 c4 10             	add    $0x10,%esp
}
c0023545:	83 c4 1c             	add    $0x1c,%esp
c0023548:	5b                   	pop    %ebx
c0023549:	5e                   	pop    %esi
c002354a:	5f                   	pop    %edi
c002354b:	5d                   	pop    %ebp
c002354c:	c3                   	ret    
  ASSERT (intr_get_level () == INTR_ON);
c002354d:	83 ec 0c             	sub    $0xc,%esp
c0023550:	68 36 d9 02 c0       	push   $0xc002d936
c0023555:	68 9f cd 02 c0       	push   $0xc002cd9f
c002355a:	68 70 b9 02 c0       	push   $0xc002b970
c002355f:	68 e1 00 00 00       	push   $0xe1
c0023564:	68 15 d9 02 c0       	push   $0xc002d915
c0023569:	e8 a1 42 00 00       	call   c002780f <debug_panic>
  if (ticks > 0)
c002356e:	83 fe 00             	cmp    $0x0,%esi
c0023571:	77 c5                	ja     c0023538 <real_time_sleep+0x4a>
      real_time_delay (num, denom); 
c0023573:	89 e9                	mov    %ebp,%ecx
c0023575:	8b 44 24 08          	mov    0x8(%esp),%eax
c0023579:	8b 54 24 0c          	mov    0xc(%esp),%edx
c002357d:	e8 59 fd ff ff       	call   c00232db <real_time_delay>
}
c0023582:	eb c1                	jmp    c0023545 <real_time_sleep+0x57>

c0023584 <timer_msleep>:
{
c0023584:	83 ec 0c             	sub    $0xc,%esp
  real_time_sleep (ms, 1000);
c0023587:	b9 e8 03 00 00       	mov    $0x3e8,%ecx
c002358c:	8b 44 24 10          	mov    0x10(%esp),%eax
c0023590:	8b 54 24 14          	mov    0x14(%esp),%edx
c0023594:	e8 55 ff ff ff       	call   c00234ee <real_time_sleep>
}
c0023599:	83 c4 0c             	add    $0xc,%esp
c002359c:	c3                   	ret    

c002359d <timer_usleep>:
{
c002359d:	83 ec 0c             	sub    $0xc,%esp
  real_time_sleep (us, 1000 * 1000);
c00235a0:	b9 40 42 0f 00       	mov    $0xf4240,%ecx
c00235a5:	8b 44 24 10          	mov    0x10(%esp),%eax
c00235a9:	8b 54 24 14          	mov    0x14(%esp),%edx
c00235ad:	e8 3c ff ff ff       	call   c00234ee <real_time_sleep>
}
c00235b2:	83 c4 0c             	add    $0xc,%esp
c00235b5:	c3                   	ret    

c00235b6 <timer_nsleep>:
{
c00235b6:	83 ec 0c             	sub    $0xc,%esp
  real_time_sleep (ns, 1000 * 1000 * 1000);
c00235b9:	b9 00 ca 9a 3b       	mov    $0x3b9aca00,%ecx
c00235be:	8b 44 24 10          	mov    0x10(%esp),%eax
c00235c2:	8b 54 24 14          	mov    0x14(%esp),%edx
c00235c6:	e8 23 ff ff ff       	call   c00234ee <real_time_sleep>
}
c00235cb:	83 c4 0c             	add    $0xc,%esp
c00235ce:	c3                   	ret    

c00235cf <timer_mdelay>:
{
c00235cf:	83 ec 0c             	sub    $0xc,%esp
  real_time_delay (ms, 1000);
c00235d2:	b9 e8 03 00 00       	mov    $0x3e8,%ecx
c00235d7:	8b 44 24 10          	mov    0x10(%esp),%eax
c00235db:	8b 54 24 14          	mov    0x14(%esp),%edx
c00235df:	e8 f7 fc ff ff       	call   c00232db <real_time_delay>
}
c00235e4:	83 c4 0c             	add    $0xc,%esp
c00235e7:	c3                   	ret    

c00235e8 <timer_udelay>:
{
c00235e8:	83 ec 0c             	sub    $0xc,%esp
  real_time_delay (us, 1000 * 1000);
c00235eb:	b9 40 42 0f 00       	mov    $0xf4240,%ecx
c00235f0:	8b 44 24 10          	mov    0x10(%esp),%eax
c00235f4:	8b 54 24 14          	mov    0x14(%esp),%edx
c00235f8:	e8 de fc ff ff       	call   c00232db <real_time_delay>
}
c00235fd:	83 c4 0c             	add    $0xc,%esp
c0023600:	c3                   	ret    

c0023601 <timer_ndelay>:
{
c0023601:	83 ec 0c             	sub    $0xc,%esp
  real_time_delay (ns, 1000 * 1000 * 1000);
c0023604:	b9 00 ca 9a 3b       	mov    $0x3b9aca00,%ecx
c0023609:	8b 44 24 10          	mov    0x10(%esp),%eax
c002360d:	8b 54 24 14          	mov    0x14(%esp),%edx
c0023611:	e8 c5 fc ff ff       	call   c00232db <real_time_delay>
}
c0023616:	83 c4 0c             	add    $0xc,%esp
c0023619:	c3                   	ret    

c002361a <timer_print_stats>:
{
c002361a:	83 ec 0c             	sub    $0xc,%esp
  printf ("Timer: %"PRId64" ticks\n", timer_ticks ());
c002361d:	e8 3d fe ff ff       	call   c002345f <timer_ticks>
c0023622:	83 ec 04             	sub    $0x4,%esp
c0023625:	52                   	push   %edx
c0023626:	50                   	push   %eax
c0023627:	68 8e d9 02 c0       	push   $0xc002d98e
c002362c:	e8 30 27 00 00       	call   c0025d61 <printf>
}
c0023631:	83 c4 1c             	add    $0x1c,%esp
c0023634:	c3                   	ret    

c0023635 <map_key>:
   If found, sets *C to the corresponding character and returns
   true.
   If not found, returns false and C is ignored. */
static bool
map_key (const struct keymap k[], unsigned scancode, uint8_t *c) 
{
c0023635:	55                   	push   %ebp
c0023636:	57                   	push   %edi
c0023637:	56                   	push   %esi
c0023638:	53                   	push   %ebx
c0023639:	83 ec 08             	sub    $0x8,%esp
c002363c:	89 0c 24             	mov    %ecx,(%esp)
  for (; k->first_scancode != 0; k++)
c002363f:	8a 18                	mov    (%eax),%bl
c0023641:	84 db                	test   %bl,%bl
c0023643:	74 49                	je     c002368e <map_key+0x59>
c0023645:	89 c6                	mov    %eax,%esi
    if (scancode >= k->first_scancode
        && scancode < k->first_scancode + strlen (k->chars)) 
c0023647:	b0 00                	mov    $0x0,%al
c0023649:	eb 09                	jmp    c0023654 <map_key+0x1f>
  for (; k->first_scancode != 0; k++)
c002364b:	83 c6 08             	add    $0x8,%esi
c002364e:	8a 1e                	mov    (%esi),%bl
c0023650:	84 db                	test   %bl,%bl
c0023652:	74 30                	je     c0023684 <map_key+0x4f>
    if (scancode >= k->first_scancode
c0023654:	0f b6 db             	movzbl %bl,%ebx
c0023657:	39 d3                	cmp    %edx,%ebx
c0023659:	77 f0                	ja     c002364b <map_key+0x16>
        && scancode < k->first_scancode + strlen (k->chars)) 
c002365b:	8b 6e 04             	mov    0x4(%esi),%ebp
c002365e:	b9 ff ff ff ff       	mov    $0xffffffff,%ecx
c0023663:	89 ef                	mov    %ebp,%edi
c0023665:	f2 ae                	repnz scas %es:(%edi),%al
c0023667:	f7 d1                	not    %ecx
c0023669:	8d 4c 0b ff          	lea    -0x1(%ebx,%ecx,1),%ecx
c002366d:	39 ca                	cmp    %ecx,%edx
c002366f:	73 da                	jae    c002364b <map_key+0x16>
      {
        *c = k->chars[scancode - k->first_scancode];
c0023671:	29 da                	sub    %ebx,%edx
c0023673:	8a 44 15 00          	mov    0x0(%ebp,%edx,1),%al
c0023677:	88 44 24 07          	mov    %al,0x7(%esp)
c002367b:	8b 3c 24             	mov    (%esp),%edi
c002367e:	88 07                	mov    %al,(%edi)
        return true; 
c0023680:	b0 01                	mov    $0x1,%al
c0023682:	eb 02                	jmp    c0023686 <map_key+0x51>
      }

  return false;
c0023684:	b0 00                	mov    $0x0,%al
}
c0023686:	83 c4 08             	add    $0x8,%esp
c0023689:	5b                   	pop    %ebx
c002368a:	5e                   	pop    %esi
c002368b:	5f                   	pop    %edi
c002368c:	5d                   	pop    %ebp
c002368d:	c3                   	ret    
  return false;
c002368e:	b0 00                	mov    $0x0,%al
c0023690:	eb f4                	jmp    c0023686 <map_key+0x51>

c0023692 <keyboard_interrupt>:
{
c0023692:	55                   	push   %ebp
c0023693:	57                   	push   %edi
c0023694:	56                   	push   %esi
c0023695:	53                   	push   %ebx
c0023696:	83 ec 2c             	sub    $0x2c,%esp
  bool shift = left_shift || right_shift;
c0023699:	a0 1e 81 03 c0       	mov    0xc003811e,%al
c002369e:	89 c7                	mov    %eax,%edi
c00236a0:	84 c0                	test   %al,%al
c00236a2:	75 07                	jne    c00236ab <keyboard_interrupt+0x19>
c00236a4:	a0 1d 81 03 c0       	mov    0xc003811d,%al
c00236a9:	89 c7                	mov    %eax,%edi
  bool alt = left_alt || right_alt;
c00236ab:	a0 1c 81 03 c0       	mov    0xc003811c,%al
c00236b0:	89 c5                	mov    %eax,%ebp
c00236b2:	84 c0                	test   %al,%al
c00236b4:	75 07                	jne    c00236bd <keyboard_interrupt+0x2b>
c00236b6:	a0 1b 81 03 c0       	mov    0xc003811b,%al
c00236bb:	89 c5                	mov    %eax,%ebp
  bool ctrl = left_ctrl || right_ctrl;
c00236bd:	a0 1a 81 03 c0       	mov    0xc003811a,%al
c00236c2:	88 44 24 0f          	mov    %al,0xf(%esp)
c00236c6:	84 c0                	test   %al,%al
c00236c8:	75 09                	jne    c00236d3 <keyboard_interrupt+0x41>
c00236ca:	a0 19 81 03 c0       	mov    0xc0038119,%al
c00236cf:	88 44 24 0f          	mov    %al,0xf(%esp)
  asm volatile ("inb %w1, %b0" : "=a" (data) : "Nd" (port));
c00236d3:	e4 60                	in     $0x60,%al
  code = inb (DATA_REG);
c00236d5:	0f b6 d8             	movzbl %al,%ebx
  if (code == 0xe0)
c00236d8:	81 fb e0 00 00 00    	cmp    $0xe0,%ebx
c00236de:	74 63                	je     c0023743 <keyboard_interrupt+0xb1>
  release = (code & 0x80) != 0;
c00236e0:	89 de                	mov    %ebx,%esi
c00236e2:	81 e6 80 00 00 00    	and    $0x80,%esi
  code &= ~0x80u;
c00236e8:	80 e3 7f             	and    $0x7f,%bl
  if (code == 0x3a) 
c00236eb:	83 fb 3a             	cmp    $0x3a,%ebx
c00236ee:	74 5d                	je     c002374d <keyboard_interrupt+0xbb>
  else if (map_key (invariant_keymap, code, &c)
c00236f0:	8d 4c 24 1f          	lea    0x1f(%esp),%ecx
c00236f4:	89 da                	mov    %ebx,%edx
c00236f6:	b8 60 ba 02 c0       	mov    $0xc002ba60,%eax
c00236fb:	e8 35 ff ff ff       	call   c0023635 <map_key>
c0023700:	84 c0                	test   %al,%al
c0023702:	75 70                	jne    c0023774 <keyboard_interrupt+0xe2>
           || (!shift && map_key (unshifted_keymap, code, &c))
c0023704:	89 f8                	mov    %edi,%eax
c0023706:	84 c0                	test   %al,%al
c0023708:	74 56                	je     c0023760 <keyboard_interrupt+0xce>
           || (shift && map_key (shifted_keymap, code, &c)))
c002370a:	8d 4c 24 1f          	lea    0x1f(%esp),%ecx
c002370e:	89 da                	mov    %ebx,%edx
c0023710:	b8 e0 b9 02 c0       	mov    $0xc002b9e0,%eax
c0023715:	e8 1b ff ff ff       	call   c0023635 <map_key>
c002371a:	84 c0                	test   %al,%al
c002371c:	75 56                	jne    c0023774 <keyboard_interrupt+0xe2>
        if (key->scancode == code)
c002371e:	83 fb 2a             	cmp    $0x2a,%ebx
c0023721:	0f 84 e2 00 00 00    	je     c0023809 <keyboard_interrupt+0x177>
c0023727:	b8 a0 b9 02 c0       	mov    $0xc002b9a0,%eax
      for (key = shift_keys; key->scancode != 0; key++) 
c002372c:	83 c0 08             	add    $0x8,%eax
c002372f:	8b 10                	mov    (%eax),%edx
c0023731:	85 d2                	test   %edx,%edx
c0023733:	74 23                	je     c0023758 <keyboard_interrupt+0xc6>
        if (key->scancode == code)
c0023735:	39 d3                	cmp    %edx,%ebx
c0023737:	75 f3                	jne    c002372c <keyboard_interrupt+0x9a>
            *key->state_var = !release;
c0023739:	8b 40 04             	mov    0x4(%eax),%eax
c002373c:	85 f6                	test   %esi,%esi
c002373e:	0f 94 00             	sete   (%eax)
            break;
c0023741:	eb 15                	jmp    c0023758 <keyboard_interrupt+0xc6>
c0023743:	e4 60                	in     $0x60,%al
    code = (code << 8) | inb (DATA_REG);
c0023745:	0f b6 d8             	movzbl %al,%ebx
c0023748:	80 cf e0             	or     $0xe0,%bh
c002374b:	eb 93                	jmp    c00236e0 <keyboard_interrupt+0x4e>
      if (!release)
c002374d:	85 f6                	test   %esi,%esi
c002374f:	75 07                	jne    c0023758 <keyboard_interrupt+0xc6>
        caps_lock = !caps_lock;
c0023751:	80 35 18 81 03 c0 01 	xorb   $0x1,0xc0038118
}
c0023758:	83 c4 2c             	add    $0x2c,%esp
c002375b:	5b                   	pop    %ebx
c002375c:	5e                   	pop    %esi
c002375d:	5f                   	pop    %edi
c002375e:	5d                   	pop    %ebp
c002375f:	c3                   	ret    
           || (!shift && map_key (unshifted_keymap, code, &c))
c0023760:	8d 4c 24 1f          	lea    0x1f(%esp),%ecx
c0023764:	89 da                	mov    %ebx,%edx
c0023766:	b8 20 ba 02 c0       	mov    $0xc002ba20,%eax
c002376b:	e8 c5 fe ff ff       	call   c0023635 <map_key>
c0023770:	84 c0                	test   %al,%al
c0023772:	74 aa                	je     c002371e <keyboard_interrupt+0x8c>
      if (!release) 
c0023774:	85 f6                	test   %esi,%esi
c0023776:	75 e0                	jne    c0023758 <keyboard_interrupt+0xc6>
          if (c == 0177 && ctrl && alt)
c0023778:	8a 44 24 1f          	mov    0x1f(%esp),%al
c002377c:	3c 7f                	cmp    $0x7f,%al
c002377e:	74 4e                	je     c00237ce <keyboard_interrupt+0x13c>
          if (ctrl && c >= 0x40 && c < 0x60) 
c0023780:	80 7c 24 0f 00       	cmpb   $0x0,0xf(%esp)
c0023785:	74 08                	je     c002378f <keyboard_interrupt+0xfd>
c0023787:	8d 50 c0             	lea    -0x40(%eax),%edx
c002378a:	80 fa 1f             	cmp    $0x1f,%dl
c002378d:	76 60                	jbe    c00237ef <keyboard_interrupt+0x15d>
          else if (shift == caps_lock)
c002378f:	89 f9                	mov    %edi,%ecx
c0023791:	38 0d 18 81 03 c0    	cmp    %cl,0xc0038118
c0023797:	74 5c                	je     c00237f5 <keyboard_interrupt+0x163>
          if (alt)
c0023799:	89 e8                	mov    %ebp,%eax
c002379b:	84 c0                	test   %al,%al
c002379d:	74 05                	je     c00237a4 <keyboard_interrupt+0x112>
            c += 0x80;
c002379f:	80 44 24 1f 80       	addb   $0x80,0x1f(%esp)
          if (!input_full ())
c00237a4:	e8 c3 18 00 00       	call   c002506c <input_full>
c00237a9:	84 c0                	test   %al,%al
c00237ab:	75 ab                	jne    c0023758 <keyboard_interrupt+0xc6>
              key_cnt++;
c00237ad:	83 05 10 81 03 c0 01 	addl   $0x1,0xc0038110
c00237b4:	83 15 14 81 03 c0 00 	adcl   $0x0,0xc0038114
              input_putc (c);
c00237bb:	83 ec 0c             	sub    $0xc,%esp
c00237be:	0f b6 44 24 2b       	movzbl 0x2b(%esp),%eax
c00237c3:	50                   	push   %eax
c00237c4:	e8 f7 17 00 00       	call   c0024fc0 <input_putc>
c00237c9:	83 c4 10             	add    $0x10,%esp
c00237cc:	eb 8a                	jmp    c0023758 <keyboard_interrupt+0xc6>
          if (c == 0177 && ctrl && alt)
c00237ce:	80 7c 24 0f 00       	cmpb   $0x0,0xf(%esp)
c00237d3:	74 06                	je     c00237db <keyboard_interrupt+0x149>
c00237d5:	89 e9                	mov    %ebp,%ecx
c00237d7:	84 c9                	test   %cl,%cl
c00237d9:	75 0f                	jne    c00237ea <keyboard_interrupt+0x158>
          else if (shift == caps_lock)
c00237db:	89 f9                	mov    %edi,%ecx
c00237dd:	38 0d 18 81 03 c0    	cmp    %cl,0xc0038118
c00237e3:	75 b4                	jne    c0023799 <keyboard_interrupt+0x107>
            c = tolower (c);
c00237e5:	0f b6 c0             	movzbl %al,%eax
c00237e8:	eb 19                	jmp    c0023803 <keyboard_interrupt+0x171>
            shutdown_reboot ();
c00237ea:	e8 c9 1d 00 00       	call   c00255b8 <shutdown_reboot>
              c -= 0x40; 
c00237ef:	88 54 24 1f          	mov    %dl,0x1f(%esp)
c00237f3:	eb a4                	jmp    c0023799 <keyboard_interrupt+0x107>
            c = tolower (c);
c00237f5:	0f b6 c0             	movzbl %al,%eax
#ifndef __LIB_CTYPE_H
#define __LIB_CTYPE_H

static inline int islower (int c) { return c >= 'a' && c <= 'z'; }
static inline int isupper (int c) { return c >= 'A' && c <= 'Z'; }
c00237f8:	8d 50 bf             	lea    -0x41(%eax),%edx
static inline int isascii (int c) { return c >= 0 && c < 128; }
static inline int ispunct (int c) {
  return isprint (c) && !isalnum (c) && !isspace (c);
}

static inline int tolower (int c) { return isupper (c) ? c - 'A' + 'a' : c; }
c00237fb:	83 fa 19             	cmp    $0x19,%edx
c00237fe:	77 03                	ja     c0023803 <keyboard_interrupt+0x171>
c0023800:	83 c0 20             	add    $0x20,%eax
c0023803:	88 44 24 1f          	mov    %al,0x1f(%esp)
c0023807:	eb 90                	jmp    c0023799 <keyboard_interrupt+0x107>
      for (key = shift_keys; key->scancode != 0; key++) 
c0023809:	b8 a0 b9 02 c0       	mov    $0xc002b9a0,%eax
c002380e:	e9 26 ff ff ff       	jmp    c0023739 <keyboard_interrupt+0xa7>

c0023813 <kbd_init>:
{
c0023813:	83 ec 10             	sub    $0x10,%esp
  intr_register_ext (0x21, keyboard_interrupt, "8042 Keyboard");
c0023816:	68 a1 d9 02 c0       	push   $0xc002d9a1
c002381b:	68 92 36 02 c0       	push   $0xc0023692
c0023820:	6a 21                	push   $0x21
c0023822:	e8 ae db ff ff       	call   c00213d5 <intr_register_ext>
}
c0023827:	83 c4 1c             	add    $0x1c,%esp
c002382a:	c3                   	ret    

c002382b <kbd_print_stats>:
{
c002382b:	83 ec 10             	sub    $0x10,%esp
  printf ("Keyboard: %lld keys pressed\n", key_cnt);
c002382e:	ff 35 14 81 03 c0    	pushl  0xc0038114
c0023834:	ff 35 10 81 03 c0    	pushl  0xc0038110
c002383a:	68 af d9 02 c0       	push   $0xc002d9af
c002383f:	e8 1d 25 00 00       	call   c0025d61 <printf>
}
c0023844:	83 c4 1c             	add    $0x1c,%esp
c0023847:	c3                   	ret    

c0023848 <move_cursor>:
/* Moves the hardware cursor to (cx,cy). */
static void
move_cursor (void) 
{
  /* See [FREEVGA] under "Manipulating the Text-mode Cursor". */
  uint16_t cp = cx + COL_CNT * cy;
c0023848:	a1 28 81 03 c0       	mov    0xc0038128,%eax
c002384d:	8d 0c 85 00 00 00 00 	lea    0x0(,%eax,4),%ecx
c0023854:	01 c1                	add    %eax,%ecx
c0023856:	c1 e1 04             	shl    $0x4,%ecx
c0023859:	03 0d 2c 81 03 c0    	add    0xc003812c,%ecx
  outw (0x3d4, 0x0e | (cp & 0xff00));
c002385f:	89 c8                	mov    %ecx,%eax
c0023861:	b0 00                	mov    $0x0,%al
c0023863:	83 c8 0e             	or     $0xe,%eax
/* Writes the 16-bit DATA to PORT. */
static inline void
outw (uint16_t port, uint16_t data)
{
  /* See [IA32-v2b] "OUT". */
  asm volatile ("outw %w0, %w1" : : "a" (data), "Nd" (port));
c0023866:	ba d4 03 00 00       	mov    $0x3d4,%edx
c002386b:	66 ef                	out    %ax,(%dx)
  outw (0x3d4, 0x0f | (cp << 8));
c002386d:	89 c8                	mov    %ecx,%eax
c002386f:	c1 e0 08             	shl    $0x8,%eax
c0023872:	83 c8 0f             	or     $0xf,%eax
c0023875:	66 ef                	out    %ax,(%dx)
c0023877:	c3                   	ret    

c0023878 <newline>:
  cx = 0;
c0023878:	c7 05 2c 81 03 c0 00 	movl   $0x0,0xc003812c
c002387f:	00 00 00 
  cy++;
c0023882:	a1 28 81 03 c0       	mov    0xc0038128,%eax
c0023887:	40                   	inc    %eax
  if (cy >= ROW_CNT)
c0023888:	83 f8 18             	cmp    $0x18,%eax
c002388b:	77 06                	ja     c0023893 <newline+0x1b>
  cy++;
c002388d:	a3 28 81 03 c0       	mov    %eax,0xc0038128
c0023892:	c3                   	ret    
{
c0023893:	53                   	push   %ebx
c0023894:	83 ec 0c             	sub    $0xc,%esp
      cy = ROW_CNT - 1;
c0023897:	c7 05 28 81 03 c0 18 	movl   $0x18,0xc0038128
c002389e:	00 00 00 
      memmove (&fb[0], &fb[1], sizeof fb[0] * (ROW_CNT - 1));
c00238a1:	8b 1d 24 81 03 c0    	mov    0xc0038124,%ebx
c00238a7:	68 00 0f 00 00       	push   $0xf00
c00238ac:	8d 83 a0 00 00 00    	lea    0xa0(%ebx),%eax
c00238b2:	50                   	push   %eax
c00238b3:	53                   	push   %ebx
c00238b4:	e8 71 32 00 00       	call   c0026b2a <memmove>
c00238b9:	8d 83 00 0f 00 00    	lea    0xf00(%ebx),%eax
c00238bf:	8d 93 a0 0f 00 00    	lea    0xfa0(%ebx),%edx
c00238c5:	83 c4 10             	add    $0x10,%esp
      fb[y][x][0] = ' ';
c00238c8:	c6 00 20             	movb   $0x20,(%eax)
      fb[y][x][1] = GRAY_ON_BLACK;
c00238cb:	c6 40 01 07          	movb   $0x7,0x1(%eax)
c00238cf:	83 c0 02             	add    $0x2,%eax
  for (x = 0; x < COL_CNT; x++)
c00238d2:	39 d0                	cmp    %edx,%eax
c00238d4:	75 f2                	jne    c00238c8 <newline+0x50>
}
c00238d6:	83 c4 08             	add    $0x8,%esp
c00238d9:	5b                   	pop    %ebx
c00238da:	c3                   	ret    

c00238db <vga_putc>:
{
c00238db:	56                   	push   %esi
c00238dc:	53                   	push   %ebx
c00238dd:	83 ec 04             	sub    $0x4,%esp
  enum intr_level old_level = intr_disable ();
c00238e0:	e8 6f d9 ff ff       	call   c0021254 <intr_disable>
c00238e5:	89 c3                	mov    %eax,%ebx
  if (!inited)
c00238e7:	80 3d 20 81 03 c0 00 	cmpb   $0x0,0xc0038120
c00238ee:	74 17                	je     c0023907 <vga_putc+0x2c>
  switch (c) 
c00238f0:	8b 44 24 10          	mov    0x10(%esp),%eax
c00238f4:	83 e8 07             	sub    $0x7,%eax
c00238f7:	83 f8 06             	cmp    $0x6,%eax
c00238fa:	0f 87 23 01 00 00    	ja     c0023a23 <vga_putc+0x148>
c0023900:	ff 24 85 b0 ba 02 c0 	jmp    *-0x3ffd4550(,%eax,4)
      fb = ptov (0xb8000);
c0023907:	c7 05 24 81 03 c0 00 	movl   $0xc00b8000,0xc0038124
c002390e:	80 0b c0 
  asm volatile ("outb %b0, %w1" : : "a" (data), "Nd" (port));
c0023911:	ba d4 03 00 00       	mov    $0x3d4,%edx
c0023916:	b0 0e                	mov    $0xe,%al
c0023918:	ee                   	out    %al,(%dx)
  asm volatile ("inb %w1, %b0" : "=a" (data) : "Nd" (port));
c0023919:	b9 d5 03 00 00       	mov    $0x3d5,%ecx
c002391e:	89 ca                	mov    %ecx,%edx
c0023920:	ec                   	in     (%dx),%al
{
  /* See [FREEVGA] under "Manipulating the Text-mode Cursor". */
  uint16_t cp;

  outb (0x3d4, 0x0e);
  cp = inb (0x3d5) << 8;
c0023921:	89 c6                	mov    %eax,%esi
c0023923:	c1 e6 08             	shl    $0x8,%esi
  asm volatile ("outb %b0, %w1" : : "a" (data), "Nd" (port));
c0023926:	ba d4 03 00 00       	mov    $0x3d4,%edx
c002392b:	b0 0f                	mov    $0xf,%al
c002392d:	ee                   	out    %al,(%dx)
  asm volatile ("inb %w1, %b0" : "=a" (data) : "Nd" (port));
c002392e:	89 ca                	mov    %ecx,%edx
c0023930:	ec                   	in     (%dx),%al

  outb (0x3d4, 0x0f);
  cp |= inb (0x3d5);
c0023931:	0f b6 c0             	movzbl %al,%eax
c0023934:	09 f0                	or     %esi,%eax
c0023936:	89 c1                	mov    %eax,%ecx

  *x = cp % COL_CNT;
c0023938:	be 50 00 00 00       	mov    $0x50,%esi
c002393d:	ba 00 00 00 00       	mov    $0x0,%edx
c0023942:	66 f7 f6             	div    %si
c0023945:	0f b7 d2             	movzwl %dx,%edx
c0023948:	89 15 2c 81 03 c0    	mov    %edx,0xc003812c
  *y = cp / COL_CNT;
c002394e:	0f b7 c1             	movzwl %cx,%eax
c0023951:	8d 14 80             	lea    (%eax,%eax,4),%edx
c0023954:	8d 14 92             	lea    (%edx,%edx,4),%edx
c0023957:	01 d2                	add    %edx,%edx
c0023959:	01 c2                	add    %eax,%edx
c002395b:	89 d1                	mov    %edx,%ecx
c002395d:	c1 e1 08             	shl    $0x8,%ecx
c0023960:	01 ca                	add    %ecx,%edx
c0023962:	8d 04 90             	lea    (%eax,%edx,4),%eax
c0023965:	c1 e8 16             	shr    $0x16,%eax
c0023968:	a3 28 81 03 c0       	mov    %eax,0xc0038128
      inited = true; 
c002396d:	c6 05 20 81 03 c0 01 	movb   $0x1,0xc0038120
c0023974:	e9 77 ff ff ff       	jmp    c00238f0 <vga_putc+0x15>
      fb[y][x][0] = ' ';
c0023979:	a1 24 81 03 c0       	mov    0xc0038124,%eax
c002397e:	8d 88 a0 0f 00 00    	lea    0xfa0(%eax),%ecx
c0023984:	8d 90 a0 00 00 00    	lea    0xa0(%eax),%edx
c002398a:	c6 00 20             	movb   $0x20,(%eax)
      fb[y][x][1] = GRAY_ON_BLACK;
c002398d:	c6 40 01 07          	movb   $0x7,0x1(%eax)
c0023991:	83 c0 02             	add    $0x2,%eax
  for (x = 0; x < COL_CNT; x++)
c0023994:	39 d0                	cmp    %edx,%eax
c0023996:	75 f2                	jne    c002398a <vga_putc+0xaf>
c0023998:	89 d0                	mov    %edx,%eax
  for (y = 0; y < ROW_CNT; y++)
c002399a:	39 d1                	cmp    %edx,%ecx
c002399c:	75 e6                	jne    c0023984 <vga_putc+0xa9>
  cx = cy = 0;
c002399e:	c7 05 28 81 03 c0 00 	movl   $0x0,0xc0038128
c00239a5:	00 00 00 
c00239a8:	c7 05 2c 81 03 c0 00 	movl   $0x0,0xc003812c
c00239af:	00 00 00 
  move_cursor ();
c00239b2:	e8 91 fe ff ff       	call   c0023848 <move_cursor>
c00239b7:	eb 05                	jmp    c00239be <vga_putc+0xe3>
      newline ();
c00239b9:	e8 ba fe ff ff       	call   c0023878 <newline>
  move_cursor ();
c00239be:	e8 85 fe ff ff       	call   c0023848 <move_cursor>
  intr_set_level (old_level);
c00239c3:	83 ec 0c             	sub    $0xc,%esp
c00239c6:	53                   	push   %ebx
c00239c7:	e8 8f d8 ff ff       	call   c002125b <intr_set_level>
}
c00239cc:	83 c4 14             	add    $0x14,%esp
c00239cf:	5b                   	pop    %ebx
c00239d0:	5e                   	pop    %esi
c00239d1:	c3                   	ret    
      if (cx > 0)
c00239d2:	a1 2c 81 03 c0       	mov    0xc003812c,%eax
c00239d7:	85 c0                	test   %eax,%eax
c00239d9:	74 e3                	je     c00239be <vga_putc+0xe3>
        cx--;
c00239db:	48                   	dec    %eax
c00239dc:	a3 2c 81 03 c0       	mov    %eax,0xc003812c
c00239e1:	eb db                	jmp    c00239be <vga_putc+0xe3>
      cx = 0;
c00239e3:	c7 05 2c 81 03 c0 00 	movl   $0x0,0xc003812c
c00239ea:	00 00 00 
      break;
c00239ed:	eb cf                	jmp    c00239be <vga_putc+0xe3>
      cx = ROUND_UP (cx + 1, 8);
c00239ef:	a1 2c 81 03 c0       	mov    0xc003812c,%eax
c00239f4:	83 c0 08             	add    $0x8,%eax
c00239f7:	83 e0 f8             	and    $0xfffffff8,%eax
c00239fa:	a3 2c 81 03 c0       	mov    %eax,0xc003812c
      if (cx >= COL_CNT)
c00239ff:	83 f8 4f             	cmp    $0x4f,%eax
c0023a02:	76 ba                	jbe    c00239be <vga_putc+0xe3>
        newline ();
c0023a04:	e8 6f fe ff ff       	call   c0023878 <newline>
c0023a09:	eb b3                	jmp    c00239be <vga_putc+0xe3>
      intr_set_level (old_level);
c0023a0b:	83 ec 0c             	sub    $0xc,%esp
c0023a0e:	53                   	push   %ebx
c0023a0f:	e8 47 d8 ff ff       	call   c002125b <intr_set_level>
      speaker_beep ();
c0023a14:	e8 0e 1d 00 00       	call   c0025727 <speaker_beep>
      intr_disable ();
c0023a19:	e8 36 d8 ff ff       	call   c0021254 <intr_disable>
      break;
c0023a1e:	83 c4 10             	add    $0x10,%esp
c0023a21:	eb 9b                	jmp    c00239be <vga_putc+0xe3>
      fb[cy][cx][0] = c;
c0023a23:	8b 35 24 81 03 c0    	mov    0xc0038124,%esi
c0023a29:	a1 28 81 03 c0       	mov    0xc0038128,%eax
c0023a2e:	8d 04 80             	lea    (%eax,%eax,4),%eax
c0023a31:	c1 e0 05             	shl    $0x5,%eax
c0023a34:	01 f0                	add    %esi,%eax
c0023a36:	8b 0d 2c 81 03 c0    	mov    0xc003812c,%ecx
c0023a3c:	8a 54 24 10          	mov    0x10(%esp),%dl
c0023a40:	88 14 48             	mov    %dl,(%eax,%ecx,2)
      fb[cy][cx][1] = GRAY_ON_BLACK;
c0023a43:	a1 28 81 03 c0       	mov    0xc0038128,%eax
c0023a48:	8d 04 80             	lea    (%eax,%eax,4),%eax
c0023a4b:	c1 e0 05             	shl    $0x5,%eax
c0023a4e:	8d 14 06             	lea    (%esi,%eax,1),%edx
c0023a51:	a1 2c 81 03 c0       	mov    0xc003812c,%eax
c0023a56:	c6 44 42 01 07       	movb   $0x7,0x1(%edx,%eax,2)
      if (++cx >= COL_CNT)
c0023a5b:	a1 2c 81 03 c0       	mov    0xc003812c,%eax
c0023a60:	40                   	inc    %eax
c0023a61:	a3 2c 81 03 c0       	mov    %eax,0xc003812c
c0023a66:	83 f8 4f             	cmp    $0x4f,%eax
c0023a69:	0f 86 4f ff ff ff    	jbe    c00239be <vga_putc+0xe3>
        newline ();
c0023a6f:	e8 04 fe ff ff       	call   c0023878 <newline>
c0023a74:	e9 45 ff ff ff       	jmp    c00239be <vga_putc+0xe3>

c0023a79 <init_poll>:
   Polling mode busy-waits for the serial port to become free
   before writing to it.  It's slow, but until interrupts have
   been initialized it's all we can do. */
static void
init_poll (void) 
{
c0023a79:	83 ec 0c             	sub    $0xc,%esp
  ASSERT (mode == UNINIT);
c0023a7c:	83 3d a8 81 03 c0 00 	cmpl   $0x0,0xc00381a8
c0023a83:	75 51                	jne    c0023ad6 <init_poll+0x5d>
  asm volatile ("outb %b0, %w1" : : "a" (data), "Nd" (port));
c0023a85:	ba f9 03 00 00       	mov    $0x3f9,%edx
c0023a8a:	b0 00                	mov    $0x0,%al
c0023a8c:	ee                   	out    %al,(%dx)
c0023a8d:	ba fa 03 00 00       	mov    $0x3fa,%edx
c0023a92:	ee                   	out    %al,(%dx)
c0023a93:	ba fb 03 00 00       	mov    $0x3fb,%edx
c0023a98:	b0 83                	mov    $0x83,%al
c0023a9a:	ee                   	out    %al,(%dx)
c0023a9b:	ba f8 03 00 00       	mov    $0x3f8,%edx
c0023aa0:	b0 0c                	mov    $0xc,%al
c0023aa2:	ee                   	out    %al,(%dx)
c0023aa3:	ba f9 03 00 00       	mov    $0x3f9,%edx
c0023aa8:	b0 00                	mov    $0x0,%al
c0023aaa:	ee                   	out    %al,(%dx)
c0023aab:	ba fb 03 00 00       	mov    $0x3fb,%edx
c0023ab0:	b0 03                	mov    $0x3,%al
c0023ab2:	ee                   	out    %al,(%dx)
c0023ab3:	ba fc 03 00 00       	mov    $0x3fc,%edx
c0023ab8:	b0 08                	mov    $0x8,%al
c0023aba:	ee                   	out    %al,(%dx)
  outb (IER_REG, 0);                    /* Turn off all interrupts. */
  outb (FCR_REG, 0);                    /* Disable FIFO. */
  set_serial (9600);                    /* 9.6 kbps, N-8-1. */
  outb (MCR_REG, MCR_OUT2);             /* Required to enable interrupts. */
  intq_init (&txq);
c0023abb:	83 ec 0c             	sub    $0xc,%esp
c0023abe:	68 40 81 03 c0       	push   $0xc0038140
c0023ac3:	e8 df 15 00 00       	call   c00250a7 <intq_init>
  mode = POLL;
c0023ac8:	c7 05 a8 81 03 c0 01 	movl   $0x1,0xc00381a8
c0023acf:	00 00 00 
} 
c0023ad2:	83 c4 1c             	add    $0x1c,%esp
c0023ad5:	c3                   	ret    
  ASSERT (mode == UNINIT);
c0023ad6:	83 ec 0c             	sub    $0xc,%esp
c0023ad9:	68 28 da 02 c0       	push   $0xc002da28
c0023ade:	68 9f cd 02 c0       	push   $0xc002cd9f
c0023ae3:	68 f4 ba 02 c0       	push   $0xc002baf4
c0023ae8:	6a 45                	push   $0x45
c0023aea:	68 37 da 02 c0       	push   $0xc002da37
c0023aef:	e8 1b 3d 00 00       	call   c002780f <debug_panic>

c0023af4 <write_ier>:
}

/* Update interrupt enable register. */
static void
write_ier (void) 
{
c0023af4:	53                   	push   %ebx
c0023af5:	83 ec 08             	sub    $0x8,%esp
  uint8_t ier = 0;

  ASSERT (intr_get_level () == INTR_OFF);
c0023af8:	e8 1a d7 ff ff       	call   c0021217 <intr_get_level>
c0023afd:	85 c0                	test   %eax,%eax
c0023aff:	75 30                	jne    c0023b31 <write_ier+0x3d>

  /* Enable transmit interrupt if we have any characters to
     transmit. */
  if (!intq_empty (&txq))
c0023b01:	83 ec 0c             	sub    $0xc,%esp
c0023b04:	68 40 81 03 c0       	push   $0xc0038140
c0023b09:	e8 c8 15 00 00       	call   c00250d6 <intq_empty>
c0023b0e:	83 c4 10             	add    $0x10,%esp
c0023b11:	84 c0                	test   %al,%al
    ier |= IER_XMIT;
c0023b13:	0f 94 c3             	sete   %bl
c0023b16:	d1 e3                	shl    %ebx

  /* Enable receive interrupt if we have room to store any
     characters we receive. */
  if (!input_full ())
c0023b18:	e8 4f 15 00 00       	call   c002506c <input_full>
c0023b1d:	84 c0                	test   %al,%al
c0023b1f:	75 03                	jne    c0023b24 <write_ier+0x30>
    ier |= IER_RECV;
c0023b21:	83 cb 01             	or     $0x1,%ebx
c0023b24:	ba f9 03 00 00       	mov    $0x3f9,%edx
c0023b29:	88 d8                	mov    %bl,%al
c0023b2b:	ee                   	out    %al,(%dx)
  
  outb (IER_REG, ier);
}
c0023b2c:	83 c4 08             	add    $0x8,%esp
c0023b2f:	5b                   	pop    %ebx
c0023b30:	c3                   	ret    
  ASSERT (intr_get_level () == INTR_OFF);
c0023b31:	83 ec 0c             	sub    $0xc,%esp
c0023b34:	68 20 d1 02 c0       	push   $0xc002d120
c0023b39:	68 9f cd 02 c0       	push   $0xc002cd9f
c0023b3e:	68 e8 ba 02 c0       	push   $0xc002bae8
c0023b43:	68 b5 00 00 00       	push   $0xb5
c0023b48:	68 37 da 02 c0       	push   $0xc002da37
c0023b4d:	e8 bd 3c 00 00       	call   c002780f <debug_panic>

c0023b52 <serial_interrupt>:
}

/* Serial interrupt handler. */
static void
serial_interrupt (struct intr_frame *f UNUSED) 
{
c0023b52:	56                   	push   %esi
c0023b53:	53                   	push   %ebx
c0023b54:	83 ec 04             	sub    $0x4,%esp
  asm volatile ("inb %w1, %b0" : "=a" (data) : "Nd" (port));
c0023b57:	ba fa 03 00 00       	mov    $0x3fa,%edx
c0023b5c:	ec                   	in     (%dx),%al
c0023b5d:	bb fd 03 00 00       	mov    $0x3fd,%ebx
c0023b62:	be f8 03 00 00       	mov    $0x3f8,%esi
c0023b67:	eb 12                	jmp    c0023b7b <serial_interrupt+0x29>
c0023b69:	89 f2                	mov    %esi,%edx
c0023b6b:	ec                   	in     (%dx),%al
  inb (IIR_REG);

  /* As long as we have room to receive a byte, and the hardware
     has a byte for us, receive a byte.  */
  while (!input_full () && (inb (LSR_REG) & LSR_DR) != 0)
    input_putc (inb (RBR_REG));
c0023b6c:	83 ec 0c             	sub    $0xc,%esp
c0023b6f:	0f b6 c0             	movzbl %al,%eax
c0023b72:	50                   	push   %eax
c0023b73:	e8 48 14 00 00       	call   c0024fc0 <input_putc>
c0023b78:	83 c4 10             	add    $0x10,%esp
  while (!input_full () && (inb (LSR_REG) & LSR_DR) != 0)
c0023b7b:	e8 ec 14 00 00       	call   c002506c <input_full>
c0023b80:	84 c0                	test   %al,%al
c0023b82:	75 07                	jne    c0023b8b <serial_interrupt+0x39>
c0023b84:	89 da                	mov    %ebx,%edx
c0023b86:	ec                   	in     (%dx),%al
c0023b87:	a8 01                	test   $0x1,%al
c0023b89:	75 de                	jne    c0023b69 <serial_interrupt+0x17>
c0023b8b:	bb fd 03 00 00       	mov    $0x3fd,%ebx
  asm volatile ("outb %b0, %w1" : : "a" (data), "Nd" (port));
c0023b90:	be f8 03 00 00       	mov    $0x3f8,%esi
c0023b95:	eb 13                	jmp    c0023baa <serial_interrupt+0x58>

  /* As long as we have a byte to transmit, and the hardware is
     ready to accept a byte for transmission, transmit a byte. */
  while (!intq_empty (&txq) && (inb (LSR_REG) & LSR_THRE) != 0) 
    outb (THR_REG, intq_getc (&txq));
c0023b97:	83 ec 0c             	sub    $0xc,%esp
c0023b9a:	68 40 81 03 c0       	push   $0xc0038140
c0023b9f:	e8 0e 17 00 00       	call   c00252b2 <intq_getc>
c0023ba4:	89 f2                	mov    %esi,%edx
c0023ba6:	ee                   	out    %al,(%dx)
c0023ba7:	83 c4 10             	add    $0x10,%esp
  while (!intq_empty (&txq) && (inb (LSR_REG) & LSR_THRE) != 0) 
c0023baa:	83 ec 0c             	sub    $0xc,%esp
c0023bad:	68 40 81 03 c0       	push   $0xc0038140
c0023bb2:	e8 1f 15 00 00       	call   c00250d6 <intq_empty>
c0023bb7:	83 c4 10             	add    $0x10,%esp
c0023bba:	84 c0                	test   %al,%al
c0023bbc:	75 07                	jne    c0023bc5 <serial_interrupt+0x73>
  asm volatile ("inb %w1, %b0" : "=a" (data) : "Nd" (port));
c0023bbe:	89 da                	mov    %ebx,%edx
c0023bc0:	ec                   	in     (%dx),%al
c0023bc1:	a8 20                	test   $0x20,%al
c0023bc3:	75 d2                	jne    c0023b97 <serial_interrupt+0x45>

  /* Update interrupt enable register based on queue status. */
  write_ier ();
c0023bc5:	e8 2a ff ff ff       	call   c0023af4 <write_ier>
}
c0023bca:	83 c4 04             	add    $0x4,%esp
c0023bcd:	5b                   	pop    %ebx
c0023bce:	5e                   	pop    %esi
c0023bcf:	c3                   	ret    

c0023bd0 <putc_poll>:
{
c0023bd0:	53                   	push   %ebx
c0023bd1:	83 ec 08             	sub    $0x8,%esp
c0023bd4:	89 c3                	mov    %eax,%ebx
  ASSERT (intr_get_level () == INTR_OFF);
c0023bd6:	e8 3c d6 ff ff       	call   c0021217 <intr_get_level>
c0023bdb:	85 c0                	test   %eax,%eax
c0023bdd:	75 17                	jne    c0023bf6 <putc_poll+0x26>
c0023bdf:	ba fd 03 00 00       	mov    $0x3fd,%edx
c0023be4:	ec                   	in     (%dx),%al
  while ((inb (LSR_REG) & LSR_THRE) == 0)
c0023be5:	a8 20                	test   $0x20,%al
c0023be7:	74 fb                	je     c0023be4 <putc_poll+0x14>
  asm volatile ("outb %b0, %w1" : : "a" (data), "Nd" (port));
c0023be9:	ba f8 03 00 00       	mov    $0x3f8,%edx
c0023bee:	88 d8                	mov    %bl,%al
c0023bf0:	ee                   	out    %al,(%dx)
}
c0023bf1:	83 c4 08             	add    $0x8,%esp
c0023bf4:	5b                   	pop    %ebx
c0023bf5:	c3                   	ret    
  ASSERT (intr_get_level () == INTR_OFF);
c0023bf6:	83 ec 0c             	sub    $0xc,%esp
c0023bf9:	68 20 d1 02 c0       	push   $0xc002d120
c0023bfe:	68 9f cd 02 c0       	push   $0xc002cd9f
c0023c03:	68 dc ba 02 c0       	push   $0xc002badc
c0023c08:	68 c9 00 00 00       	push   $0xc9
c0023c0d:	68 37 da 02 c0       	push   $0xc002da37
c0023c12:	e8 f8 3b 00 00       	call   c002780f <debug_panic>

c0023c17 <serial_init_queue>:
{
c0023c17:	53                   	push   %ebx
c0023c18:	83 ec 08             	sub    $0x8,%esp
  if (mode == UNINIT)
c0023c1b:	83 3d a8 81 03 c0 00 	cmpl   $0x0,0xc00381a8
c0023c22:	74 40                	je     c0023c64 <serial_init_queue+0x4d>
  ASSERT (mode == POLL);
c0023c24:	83 3d a8 81 03 c0 01 	cmpl   $0x1,0xc00381a8
c0023c2b:	75 3e                	jne    c0023c6b <serial_init_queue+0x54>
  intr_register_ext (0x20 + 4, serial_interrupt, "serial");
c0023c2d:	83 ec 04             	sub    $0x4,%esp
c0023c30:	68 5b da 02 c0       	push   $0xc002da5b
c0023c35:	68 52 3b 02 c0       	push   $0xc0023b52
c0023c3a:	6a 24                	push   $0x24
c0023c3c:	e8 94 d7 ff ff       	call   c00213d5 <intr_register_ext>
  mode = QUEUE;
c0023c41:	c7 05 a8 81 03 c0 02 	movl   $0x2,0xc00381a8
c0023c48:	00 00 00 
  old_level = intr_disable ();
c0023c4b:	e8 04 d6 ff ff       	call   c0021254 <intr_disable>
c0023c50:	89 c3                	mov    %eax,%ebx
  write_ier ();
c0023c52:	e8 9d fe ff ff       	call   c0023af4 <write_ier>
  intr_set_level (old_level);
c0023c57:	89 1c 24             	mov    %ebx,(%esp)
c0023c5a:	e8 fc d5 ff ff       	call   c002125b <intr_set_level>
}
c0023c5f:	83 c4 18             	add    $0x18,%esp
c0023c62:	5b                   	pop    %ebx
c0023c63:	c3                   	ret    
    init_poll ();
c0023c64:	e8 10 fe ff ff       	call   c0023a79 <init_poll>
c0023c69:	eb b9                	jmp    c0023c24 <serial_init_queue+0xd>
  ASSERT (mode == POLL);
c0023c6b:	83 ec 0c             	sub    $0xc,%esp
c0023c6e:	68 4e da 02 c0       	push   $0xc002da4e
c0023c73:	68 9f cd 02 c0       	push   $0xc002cd9f
c0023c78:	68 00 bb 02 c0       	push   $0xc002bb00
c0023c7d:	6a 58                	push   $0x58
c0023c7f:	68 37 da 02 c0       	push   $0xc002da37
c0023c84:	e8 86 3b 00 00       	call   c002780f <debug_panic>

c0023c89 <serial_putc>:
{
c0023c89:	56                   	push   %esi
c0023c8a:	53                   	push   %ebx
c0023c8b:	83 ec 04             	sub    $0x4,%esp
c0023c8e:	8b 5c 24 10          	mov    0x10(%esp),%ebx
  enum intr_level old_level = intr_disable ();
c0023c92:	e8 bd d5 ff ff       	call   c0021254 <intr_disable>
c0023c97:	89 c6                	mov    %eax,%esi
  if (mode != QUEUE)
c0023c99:	a1 a8 81 03 c0       	mov    0xc00381a8,%eax
c0023c9e:	83 f8 02             	cmp    $0x2,%eax
c0023ca1:	74 22                	je     c0023cc5 <serial_putc+0x3c>
      if (mode == UNINIT)
c0023ca3:	85 c0                	test   %eax,%eax
c0023ca5:	74 17                	je     c0023cbe <serial_putc+0x35>
      putc_poll (byte); 
c0023ca7:	0f b6 c3             	movzbl %bl,%eax
c0023caa:	e8 21 ff ff ff       	call   c0023bd0 <putc_poll>
  intr_set_level (old_level);
c0023caf:	83 ec 0c             	sub    $0xc,%esp
c0023cb2:	56                   	push   %esi
c0023cb3:	e8 a3 d5 ff ff       	call   c002125b <intr_set_level>
}
c0023cb8:	83 c4 14             	add    $0x14,%esp
c0023cbb:	5b                   	pop    %ebx
c0023cbc:	5e                   	pop    %esi
c0023cbd:	c3                   	ret    
        init_poll ();
c0023cbe:	e8 b6 fd ff ff       	call   c0023a79 <init_poll>
c0023cc3:	eb e2                	jmp    c0023ca7 <serial_putc+0x1e>
      if (old_level == INTR_OFF && intq_full (&txq)) 
c0023cc5:	85 f6                	test   %esi,%esi
c0023cc7:	74 1b                	je     c0023ce4 <serial_putc+0x5b>
      intq_putc (&txq, byte); 
c0023cc9:	83 ec 08             	sub    $0x8,%esp
c0023ccc:	0f b6 db             	movzbl %bl,%ebx
c0023ccf:	53                   	push   %ebx
c0023cd0:	68 40 81 03 c0       	push   $0xc0038140
c0023cd5:	e8 8d 16 00 00       	call   c0025367 <intq_putc>
      write_ier ();
c0023cda:	e8 15 fe ff ff       	call   c0023af4 <write_ier>
c0023cdf:	83 c4 10             	add    $0x10,%esp
c0023ce2:	eb cb                	jmp    c0023caf <serial_putc+0x26>
      if (old_level == INTR_OFF && intq_full (&txq)) 
c0023ce4:	83 ec 0c             	sub    $0xc,%esp
c0023ce7:	68 40 81 03 c0       	push   $0xc0038140
c0023cec:	e8 22 14 00 00       	call   c0025113 <intq_full>
c0023cf1:	83 c4 10             	add    $0x10,%esp
c0023cf4:	84 c0                	test   %al,%al
c0023cf6:	74 d1                	je     c0023cc9 <serial_putc+0x40>
          putc_poll (intq_getc (&txq)); 
c0023cf8:	83 ec 0c             	sub    $0xc,%esp
c0023cfb:	68 40 81 03 c0       	push   $0xc0038140
c0023d00:	e8 ad 15 00 00       	call   c00252b2 <intq_getc>
c0023d05:	0f b6 c0             	movzbl %al,%eax
c0023d08:	e8 c3 fe ff ff       	call   c0023bd0 <putc_poll>
c0023d0d:	83 c4 10             	add    $0x10,%esp
c0023d10:	eb b7                	jmp    c0023cc9 <serial_putc+0x40>

c0023d12 <serial_flush>:
{
c0023d12:	53                   	push   %ebx
c0023d13:	83 ec 08             	sub    $0x8,%esp
  enum intr_level old_level = intr_disable ();
c0023d16:	e8 39 d5 ff ff       	call   c0021254 <intr_disable>
c0023d1b:	89 c3                	mov    %eax,%ebx
  while (!intq_empty (&txq))
c0023d1d:	eb 18                	jmp    c0023d37 <serial_flush+0x25>
    putc_poll (intq_getc (&txq));
c0023d1f:	83 ec 0c             	sub    $0xc,%esp
c0023d22:	68 40 81 03 c0       	push   $0xc0038140
c0023d27:	e8 86 15 00 00       	call   c00252b2 <intq_getc>
c0023d2c:	0f b6 c0             	movzbl %al,%eax
c0023d2f:	e8 9c fe ff ff       	call   c0023bd0 <putc_poll>
c0023d34:	83 c4 10             	add    $0x10,%esp
  while (!intq_empty (&txq))
c0023d37:	83 ec 0c             	sub    $0xc,%esp
c0023d3a:	68 40 81 03 c0       	push   $0xc0038140
c0023d3f:	e8 92 13 00 00       	call   c00250d6 <intq_empty>
c0023d44:	83 c4 10             	add    $0x10,%esp
c0023d47:	84 c0                	test   %al,%al
c0023d49:	74 d4                	je     c0023d1f <serial_flush+0xd>
  intr_set_level (old_level);
c0023d4b:	83 ec 0c             	sub    $0xc,%esp
c0023d4e:	53                   	push   %ebx
c0023d4f:	e8 07 d5 ff ff       	call   c002125b <intr_set_level>
}
c0023d54:	83 c4 18             	add    $0x18,%esp
c0023d57:	5b                   	pop    %ebx
c0023d58:	c3                   	ret    

c0023d59 <serial_notify>:
{
c0023d59:	83 ec 0c             	sub    $0xc,%esp
  ASSERT (intr_get_level () == INTR_OFF);
c0023d5c:	e8 b6 d4 ff ff       	call   c0021217 <intr_get_level>
c0023d61:	85 c0                	test   %eax,%eax
c0023d63:	75 0d                	jne    c0023d72 <serial_notify+0x19>
  if (mode == QUEUE)
c0023d65:	83 3d a8 81 03 c0 02 	cmpl   $0x2,0xc00381a8
c0023d6c:	74 25                	je     c0023d93 <serial_notify+0x3a>
}
c0023d6e:	83 c4 0c             	add    $0xc,%esp
c0023d71:	c3                   	ret    
  ASSERT (intr_get_level () == INTR_OFF);
c0023d72:	83 ec 0c             	sub    $0xc,%esp
c0023d75:	68 20 d1 02 c0       	push   $0xc002d120
c0023d7a:	68 9f cd 02 c0       	push   $0xc002cd9f
c0023d7f:	68 cc ba 02 c0       	push   $0xc002bacc
c0023d84:	68 96 00 00 00       	push   $0x96
c0023d89:	68 37 da 02 c0       	push   $0xc002da37
c0023d8e:	e8 7c 3a 00 00       	call   c002780f <debug_panic>
    write_ier ();
c0023d93:	e8 5c fd ff ff       	call   c0023af4 <write_ier>
}
c0023d98:	eb d4                	jmp    c0023d6e <serial_notify+0x15>

c0023d9a <check_sector>:
/* Verifies that SECTOR is a valid offset within BLOCK.
   Panics if not. */
static void
check_sector (struct block *block, block_sector_t sector)
{
  if (sector >= block->size)
c0023d9a:	8b 48 1c             	mov    0x1c(%eax),%ecx
c0023d9d:	39 d1                	cmp    %edx,%ecx
c0023d9f:	76 01                	jbe    c0023da2 <check_sector+0x8>
c0023da1:	c3                   	ret    
{
c0023da2:	83 ec 10             	sub    $0x10,%esp
    {
      /* We do not use ASSERT because we want to panic here
         regardless of whether NDEBUG is defined. */
      PANIC ("Access past end of device %s (sector=%"PRDSNu", "
c0023da5:	51                   	push   %ecx
c0023da6:	52                   	push   %edx

/* Returns BLOCK's name (e.g. "hda"). */
const char *
block_name (struct block *block)
{
  return block->name;
c0023da7:	83 c0 08             	add    $0x8,%eax
      PANIC ("Access past end of device %s (sector=%"PRDSNu", "
c0023daa:	50                   	push   %eax
c0023dab:	68 64 da 02 c0       	push   $0xc002da64
c0023db0:	68 30 bb 02 c0       	push   $0xc002bb30
c0023db5:	6a 70                	push   $0x70
c0023db7:	68 f2 da 02 c0       	push   $0xc002daf2
c0023dbc:	e8 4e 3a 00 00       	call   c002780f <debug_panic>

c0023dc1 <block_type_name>:
{
c0023dc1:	83 ec 0c             	sub    $0xc,%esp
c0023dc4:	8b 44 24 10          	mov    0x10(%esp),%eax
  ASSERT (type < BLOCK_CNT);
c0023dc8:	83 f8 05             	cmp    $0x5,%eax
c0023dcb:	77 0b                	ja     c0023dd8 <block_type_name+0x17>
  return block_type_names[type];
c0023dcd:	8b 04 85 60 bb 02 c0 	mov    -0x3ffd44a0(,%eax,4),%eax
}
c0023dd4:	83 c4 0c             	add    $0xc,%esp
c0023dd7:	c3                   	ret    
  ASSERT (type < BLOCK_CNT);
c0023dd8:	83 ec 0c             	sub    $0xc,%esp
c0023ddb:	68 08 db 02 c0       	push   $0xc002db08
c0023de0:	68 9f cd 02 c0       	push   $0xc002cd9f
c0023de5:	68 78 bb 02 c0       	push   $0xc002bb78
c0023dea:	6a 2f                	push   $0x2f
c0023dec:	68 f2 da 02 c0       	push   $0xc002daf2
c0023df1:	e8 19 3a 00 00       	call   c002780f <debug_panic>

c0023df6 <block_get_role>:
{
c0023df6:	83 ec 0c             	sub    $0xc,%esp
c0023df9:	8b 44 24 10          	mov    0x10(%esp),%eax
  ASSERT (role < BLOCK_ROLE_CNT);
c0023dfd:	83 f8 03             	cmp    $0x3,%eax
c0023e00:	77 0b                	ja     c0023e0d <block_get_role+0x17>
  return block_by_role[role];
c0023e02:	8b 04 85 ac 81 03 c0 	mov    -0x3ffc7e54(,%eax,4),%eax
}
c0023e09:	83 c4 0c             	add    $0xc,%esp
c0023e0c:	c3                   	ret    
  ASSERT (role < BLOCK_ROLE_CNT);
c0023e0d:	83 ec 0c             	sub    $0xc,%esp
c0023e10:	68 19 db 02 c0       	push   $0xc002db19
c0023e15:	68 9f cd 02 c0       	push   $0xc002cd9f
c0023e1a:	68 50 bb 02 c0       	push   $0xc002bb50
c0023e1f:	6a 38                	push   $0x38
c0023e21:	68 f2 da 02 c0       	push   $0xc002daf2
c0023e26:	e8 e4 39 00 00       	call   c002780f <debug_panic>

c0023e2b <block_set_role>:
{
c0023e2b:	83 ec 0c             	sub    $0xc,%esp
c0023e2e:	8b 44 24 10          	mov    0x10(%esp),%eax
  ASSERT (role < BLOCK_ROLE_CNT);
c0023e32:	83 f8 03             	cmp    $0x3,%eax
c0023e35:	77 0f                	ja     c0023e46 <block_set_role+0x1b>
  block_by_role[role] = block;
c0023e37:	8b 54 24 14          	mov    0x14(%esp),%edx
c0023e3b:	89 14 85 ac 81 03 c0 	mov    %edx,-0x3ffc7e54(,%eax,4)
}
c0023e42:	83 c4 0c             	add    $0xc,%esp
c0023e45:	c3                   	ret    
  ASSERT (role < BLOCK_ROLE_CNT);
c0023e46:	83 ec 0c             	sub    $0xc,%esp
c0023e49:	68 19 db 02 c0       	push   $0xc002db19
c0023e4e:	68 9f cd 02 c0       	push   $0xc002cd9f
c0023e53:	68 40 bb 02 c0       	push   $0xc002bb40
c0023e58:	6a 40                	push   $0x40
c0023e5a:	68 f2 da 02 c0       	push   $0xc002daf2
c0023e5f:	e8 ab 39 00 00       	call   c002780f <debug_panic>

c0023e64 <block_first>:
{
c0023e64:	53                   	push   %ebx
c0023e65:	83 ec 14             	sub    $0x14,%esp
  return list_elem_to_block (list_begin (&all_blocks));
c0023e68:	68 cc 68 03 c0       	push   $0xc00368cc
c0023e6d:	e8 87 3a 00 00       	call   c00278f9 <list_begin>
c0023e72:	89 c3                	mov    %eax,%ebx
/* Returns the block device corresponding to LIST_ELEM, or a null
   pointer if LIST_ELEM is the list end of all_blocks. */
static struct block *
list_elem_to_block (struct list_elem *list_elem)
{
  return (list_elem != list_end (&all_blocks)
c0023e74:	c7 04 24 cc 68 03 c0 	movl   $0xc00368cc,(%esp)
c0023e7b:	e8 f1 3a 00 00       	call   c0027971 <list_end>
          ? list_entry (list_elem, struct block, list_elem)
          : NULL);
c0023e80:	83 c4 10             	add    $0x10,%esp
c0023e83:	39 c3                	cmp    %eax,%ebx
c0023e85:	74 07                	je     c0023e8e <block_first+0x2a>
c0023e87:	89 d8                	mov    %ebx,%eax
}
c0023e89:	83 c4 08             	add    $0x8,%esp
c0023e8c:	5b                   	pop    %ebx
c0023e8d:	c3                   	ret    
          : NULL);
c0023e8e:	b8 00 00 00 00       	mov    $0x0,%eax
  return list_elem_to_block (list_begin (&all_blocks));
c0023e93:	eb f4                	jmp    c0023e89 <block_first+0x25>

c0023e95 <block_next>:
{
c0023e95:	53                   	push   %ebx
c0023e96:	83 ec 14             	sub    $0x14,%esp
  return list_elem_to_block (list_next (&block->list_elem));
c0023e99:	ff 74 24 1c          	pushl  0x1c(%esp)
c0023e9d:	e8 87 3a 00 00       	call   c0027929 <list_next>
c0023ea2:	89 c3                	mov    %eax,%ebx
  return (list_elem != list_end (&all_blocks)
c0023ea4:	c7 04 24 cc 68 03 c0 	movl   $0xc00368cc,(%esp)
c0023eab:	e8 c1 3a 00 00       	call   c0027971 <list_end>
          : NULL);
c0023eb0:	83 c4 10             	add    $0x10,%esp
c0023eb3:	39 c3                	cmp    %eax,%ebx
c0023eb5:	74 07                	je     c0023ebe <block_next+0x29>
c0023eb7:	89 d8                	mov    %ebx,%eax
}
c0023eb9:	83 c4 08             	add    $0x8,%esp
c0023ebc:	5b                   	pop    %ebx
c0023ebd:	c3                   	ret    
          : NULL);
c0023ebe:	b8 00 00 00 00       	mov    $0x0,%eax
  return list_elem_to_block (list_next (&block->list_elem));
c0023ec3:	eb f4                	jmp    c0023eb9 <block_next+0x24>

c0023ec5 <block_get_by_name>:
{
c0023ec5:	56                   	push   %esi
c0023ec6:	53                   	push   %ebx
c0023ec7:	83 ec 10             	sub    $0x10,%esp
c0023eca:	8b 74 24 1c          	mov    0x1c(%esp),%esi
  for (e = list_begin (&all_blocks); e != list_end (&all_blocks);
c0023ece:	68 cc 68 03 c0       	push   $0xc00368cc
c0023ed3:	e8 21 3a 00 00       	call   c00278f9 <list_begin>
c0023ed8:	89 c3                	mov    %eax,%ebx
c0023eda:	83 c4 10             	add    $0x10,%esp
c0023edd:	83 ec 0c             	sub    $0xc,%esp
c0023ee0:	68 cc 68 03 c0       	push   $0xc00368cc
c0023ee5:	e8 87 3a 00 00       	call   c0027971 <list_end>
c0023eea:	83 c4 10             	add    $0x10,%esp
c0023eed:	39 c3                	cmp    %eax,%ebx
c0023eef:	74 24                	je     c0023f15 <block_get_by_name+0x50>
      if (!strcmp (name, block->name))
c0023ef1:	8d 43 08             	lea    0x8(%ebx),%eax
c0023ef4:	83 ec 08             	sub    $0x8,%esp
c0023ef7:	50                   	push   %eax
c0023ef8:	56                   	push   %esi
c0023ef9:	e8 c6 2c 00 00       	call   c0026bc4 <strcmp>
c0023efe:	83 c4 10             	add    $0x10,%esp
c0023f01:	85 c0                	test   %eax,%eax
c0023f03:	74 1b                	je     c0023f20 <block_get_by_name+0x5b>
       e = list_next (e))
c0023f05:	83 ec 0c             	sub    $0xc,%esp
c0023f08:	53                   	push   %ebx
c0023f09:	e8 1b 3a 00 00       	call   c0027929 <list_next>
c0023f0e:	89 c3                	mov    %eax,%ebx
c0023f10:	83 c4 10             	add    $0x10,%esp
c0023f13:	eb c8                	jmp    c0023edd <block_get_by_name+0x18>
  return NULL;
c0023f15:	b8 00 00 00 00       	mov    $0x0,%eax
}
c0023f1a:	83 c4 04             	add    $0x4,%esp
c0023f1d:	5b                   	pop    %ebx
c0023f1e:	5e                   	pop    %esi
c0023f1f:	c3                   	ret    
c0023f20:	89 d8                	mov    %ebx,%eax
c0023f22:	eb f6                	jmp    c0023f1a <block_get_by_name+0x55>

c0023f24 <block_read>:
{
c0023f24:	56                   	push   %esi
c0023f25:	53                   	push   %ebx
c0023f26:	83 ec 04             	sub    $0x4,%esp
c0023f29:	8b 5c 24 10          	mov    0x10(%esp),%ebx
c0023f2d:	8b 74 24 14          	mov    0x14(%esp),%esi
  check_sector (block, sector);
c0023f31:	89 f2                	mov    %esi,%edx
c0023f33:	89 d8                	mov    %ebx,%eax
c0023f35:	e8 60 fe ff ff       	call   c0023d9a <check_sector>
  block->ops->read (block->aux, sector, buffer);
c0023f3a:	83 ec 04             	sub    $0x4,%esp
c0023f3d:	8b 43 20             	mov    0x20(%ebx),%eax
c0023f40:	ff 74 24 1c          	pushl  0x1c(%esp)
c0023f44:	56                   	push   %esi
c0023f45:	ff 73 24             	pushl  0x24(%ebx)
c0023f48:	ff 10                	call   *(%eax)
  block->read_cnt++;
c0023f4a:	83 43 28 01          	addl   $0x1,0x28(%ebx)
c0023f4e:	83 53 2c 00          	adcl   $0x0,0x2c(%ebx)
}
c0023f52:	83 c4 14             	add    $0x14,%esp
c0023f55:	5b                   	pop    %ebx
c0023f56:	5e                   	pop    %esi
c0023f57:	c3                   	ret    

c0023f58 <block_write>:
{
c0023f58:	56                   	push   %esi
c0023f59:	53                   	push   %ebx
c0023f5a:	83 ec 04             	sub    $0x4,%esp
c0023f5d:	8b 5c 24 10          	mov    0x10(%esp),%ebx
c0023f61:	8b 74 24 14          	mov    0x14(%esp),%esi
  check_sector (block, sector);
c0023f65:	89 f2                	mov    %esi,%edx
c0023f67:	89 d8                	mov    %ebx,%eax
c0023f69:	e8 2c fe ff ff       	call   c0023d9a <check_sector>
  ASSERT (block->type != BLOCK_FOREIGN);
c0023f6e:	83 7b 18 05          	cmpl   $0x5,0x18(%ebx)
c0023f72:	74 1f                	je     c0023f93 <block_write+0x3b>
  block->ops->write (block->aux, sector, buffer);
c0023f74:	83 ec 04             	sub    $0x4,%esp
c0023f77:	8b 43 20             	mov    0x20(%ebx),%eax
c0023f7a:	ff 74 24 1c          	pushl  0x1c(%esp)
c0023f7e:	56                   	push   %esi
c0023f7f:	ff 73 24             	pushl  0x24(%ebx)
c0023f82:	ff 50 04             	call   *0x4(%eax)
  block->write_cnt++;
c0023f85:	83 43 30 01          	addl   $0x1,0x30(%ebx)
c0023f89:	83 53 34 00          	adcl   $0x0,0x34(%ebx)
}
c0023f8d:	83 c4 14             	add    $0x14,%esp
c0023f90:	5b                   	pop    %ebx
c0023f91:	5e                   	pop    %esi
c0023f92:	c3                   	ret    
  ASSERT (block->type != BLOCK_FOREIGN);
c0023f93:	83 ec 0c             	sub    $0xc,%esp
c0023f96:	68 2f db 02 c0       	push   $0xc002db2f
c0023f9b:	68 9f cd 02 c0       	push   $0xc002cd9f
c0023fa0:	68 24 bb 02 c0       	push   $0xc002bb24
c0023fa5:	68 89 00 00 00       	push   $0x89
c0023faa:	68 f2 da 02 c0       	push   $0xc002daf2
c0023faf:	e8 5b 38 00 00       	call   c002780f <debug_panic>

c0023fb4 <block_size>:
  return block->size;
c0023fb4:	8b 44 24 04          	mov    0x4(%esp),%eax
c0023fb8:	8b 40 1c             	mov    0x1c(%eax),%eax
}
c0023fbb:	c3                   	ret    

c0023fbc <block_name>:
  return block->name;
c0023fbc:	8b 44 24 04          	mov    0x4(%esp),%eax
c0023fc0:	83 c0 08             	add    $0x8,%eax
}
c0023fc3:	c3                   	ret    

c0023fc4 <block_type>:
  return block->type;
c0023fc4:	8b 44 24 04          	mov    0x4(%esp),%eax
c0023fc8:	8b 40 18             	mov    0x18(%eax),%eax
}
c0023fcb:	c3                   	ret    

c0023fcc <block_print_stats>:
{
c0023fcc:	57                   	push   %edi
c0023fcd:	56                   	push   %esi
c0023fce:	53                   	push   %ebx
c0023fcf:	be ac 81 03 c0       	mov    $0xc00381ac,%esi
c0023fd4:	bf bc 81 03 c0       	mov    $0xc00381bc,%edi
c0023fd9:	eb 07                	jmp    c0023fe2 <block_print_stats+0x16>
c0023fdb:	83 c6 04             	add    $0x4,%esi
  for (i = 0; i < BLOCK_ROLE_CNT; i++)
c0023fde:	39 fe                	cmp    %edi,%esi
c0023fe0:	74 34                	je     c0024016 <block_print_stats+0x4a>
      struct block *block = block_by_role[i];
c0023fe2:	8b 1e                	mov    (%esi),%ebx
      if (block != NULL)
c0023fe4:	85 db                	test   %ebx,%ebx
c0023fe6:	74 f3                	je     c0023fdb <block_print_stats+0xf>
          printf ("%s (%s): %llu reads, %llu writes\n",
c0023fe8:	83 ec 0c             	sub    $0xc,%esp
c0023feb:	ff 73 18             	pushl  0x18(%ebx)
c0023fee:	e8 ce fd ff ff       	call   c0023dc1 <block_type_name>
c0023ff3:	83 c4 0c             	add    $0xc,%esp
c0023ff6:	ff 73 34             	pushl  0x34(%ebx)
c0023ff9:	ff 73 30             	pushl  0x30(%ebx)
c0023ffc:	ff 73 2c             	pushl  0x2c(%ebx)
c0023fff:	ff 73 28             	pushl  0x28(%ebx)
c0024002:	50                   	push   %eax
c0024003:	83 c3 08             	add    $0x8,%ebx
c0024006:	53                   	push   %ebx
c0024007:	68 98 da 02 c0       	push   $0xc002da98
c002400c:	e8 50 1d 00 00       	call   c0025d61 <printf>
c0024011:	83 c4 20             	add    $0x20,%esp
c0024014:	eb c5                	jmp    c0023fdb <block_print_stats+0xf>
}
c0024016:	5b                   	pop    %ebx
c0024017:	5e                   	pop    %esi
c0024018:	5f                   	pop    %edi
c0024019:	c3                   	ret    

c002401a <block_register>:
{
c002401a:	55                   	push   %ebp
c002401b:	57                   	push   %edi
c002401c:	56                   	push   %esi
c002401d:	53                   	push   %ebx
c002401e:	83 ec 18             	sub    $0x18,%esp
c0024021:	8b 74 24 34          	mov    0x34(%esp),%esi
c0024025:	8b 7c 24 38          	mov    0x38(%esp),%edi
  struct block *block = malloc (sizeof *block);
c0024029:	6a 38                	push   $0x38
c002402b:	e8 52 ee ff ff       	call   c0022e82 <malloc>
  if (block == NULL)
c0024030:	83 c4 10             	add    $0x10,%esp
c0024033:	85 c0                	test   %eax,%eax
c0024035:	0f 84 b6 00 00 00    	je     c00240f1 <block_register+0xd7>
c002403b:	89 c3                	mov    %eax,%ebx
  list_push_back (&all_blocks, &block->list_elem);
c002403d:	83 ec 08             	sub    $0x8,%esp
c0024040:	50                   	push   %eax
c0024041:	68 cc 68 03 c0       	push   $0xc00368cc
c0024046:	e8 08 3d 00 00       	call   c0027d53 <list_push_back>
  strlcpy (block->name, name, sizeof block->name);
c002404b:	8d 6b 08             	lea    0x8(%ebx),%ebp
c002404e:	83 c4 0c             	add    $0xc,%esp
c0024051:	6a 10                	push   $0x10
c0024053:	ff 74 24 28          	pushl  0x28(%esp)
c0024057:	55                   	push   %ebp
c0024058:	e8 ac 2e 00 00       	call   c0026f09 <strlcpy>
  block->type = type;
c002405d:	8b 44 24 34          	mov    0x34(%esp),%eax
c0024061:	89 43 18             	mov    %eax,0x18(%ebx)
  block->size = size;
c0024064:	89 7b 1c             	mov    %edi,0x1c(%ebx)
  block->ops = ops;
c0024067:	8b 44 24 40          	mov    0x40(%esp),%eax
c002406b:	89 43 20             	mov    %eax,0x20(%ebx)
  block->aux = aux;
c002406e:	8b 44 24 44          	mov    0x44(%esp),%eax
c0024072:	89 43 24             	mov    %eax,0x24(%ebx)
  block->read_cnt = 0;
c0024075:	c7 43 28 00 00 00 00 	movl   $0x0,0x28(%ebx)
c002407c:	c7 43 2c 00 00 00 00 	movl   $0x0,0x2c(%ebx)
  block->write_cnt = 0;
c0024083:	c7 43 30 00 00 00 00 	movl   $0x0,0x30(%ebx)
c002408a:	c7 43 34 00 00 00 00 	movl   $0x0,0x34(%ebx)
  printf ("%s: %'"PRDSNu" sectors (", block->name, block->size);
c0024091:	83 c4 0c             	add    $0xc,%esp
c0024094:	57                   	push   %edi
c0024095:	55                   	push   %ebp
c0024096:	68 4c db 02 c0       	push   $0xc002db4c
c002409b:	e8 c1 1c 00 00       	call   c0025d61 <printf>
  print_human_readable_size ((uint64_t) block->size * BLOCK_SECTOR_SIZE);
c00240a0:	83 c4 08             	add    $0x8,%esp
c00240a3:	8b 43 1c             	mov    0x1c(%ebx),%eax
c00240a6:	ba 00 00 00 00       	mov    $0x0,%edx
c00240ab:	0f a4 c2 09          	shld   $0x9,%eax,%edx
c00240af:	c1 e0 09             	shl    $0x9,%eax
c00240b2:	52                   	push   %edx
c00240b3:	50                   	push   %eax
c00240b4:	e8 4c 26 00 00       	call   c0026705 <print_human_readable_size>
  printf (")");
c00240b9:	c7 04 24 29 00 00 00 	movl   $0x29,(%esp)
c00240c0:	e8 04 52 00 00       	call   c00292c9 <putchar>
  if (extra_info != NULL)
c00240c5:	83 c4 10             	add    $0x10,%esp
c00240c8:	85 f6                	test   %esi,%esi
c00240ca:	74 11                	je     c00240dd <block_register+0xc3>
    printf (", %s", extra_info);
c00240cc:	83 ec 08             	sub    $0x8,%esp
c00240cf:	56                   	push   %esi
c00240d0:	68 5e db 02 c0       	push   $0xc002db5e
c00240d5:	e8 87 1c 00 00       	call   c0025d61 <printf>
c00240da:	83 c4 10             	add    $0x10,%esp
  printf ("\n");
c00240dd:	83 ec 0c             	sub    $0xc,%esp
c00240e0:	6a 0a                	push   $0xa
c00240e2:	e8 e2 51 00 00       	call   c00292c9 <putchar>
}
c00240e7:	89 d8                	mov    %ebx,%eax
c00240e9:	83 c4 1c             	add    $0x1c,%esp
c00240ec:	5b                   	pop    %ebx
c00240ed:	5e                   	pop    %esi
c00240ee:	5f                   	pop    %edi
c00240ef:	5d                   	pop    %ebp
c00240f0:	c3                   	ret    
    PANIC ("Failed to allocate memory for block device descriptor");
c00240f1:	68 bc da 02 c0       	push   $0xc002dabc
c00240f6:	68 14 bb 02 c0       	push   $0xc002bb14
c00240fb:	68 c1 00 00 00       	push   $0xc1
c0024100:	68 f2 da 02 c0       	push   $0xc002daf2
c0024105:	e8 05 37 00 00       	call   c002780f <debug_panic>

c002410a <partition_read>:

/* Reads sector SECTOR from partition P into BUFFER, which must
   have room for BLOCK_SECTOR_SIZE bytes. */
static void
partition_read (void *p_, block_sector_t sector, void *buffer)
{
c002410a:	83 ec 10             	sub    $0x10,%esp
c002410d:	8b 54 24 14          	mov    0x14(%esp),%edx
  struct partition *p = p_;
  block_read (p->block, p->start + sector, buffer);
c0024111:	ff 74 24 1c          	pushl  0x1c(%esp)
c0024115:	8b 42 04             	mov    0x4(%edx),%eax
c0024118:	03 44 24 1c          	add    0x1c(%esp),%eax
c002411c:	50                   	push   %eax
c002411d:	ff 32                	pushl  (%edx)
c002411f:	e8 00 fe ff ff       	call   c0023f24 <block_read>
}
c0024124:	83 c4 1c             	add    $0x1c,%esp
c0024127:	c3                   	ret    

c0024128 <read_partition_table>:
{
c0024128:	55                   	push   %ebp
c0024129:	57                   	push   %edi
c002412a:	56                   	push   %esi
c002412b:	53                   	push   %ebx
c002412c:	81 ec c8 00 00 00    	sub    $0xc8,%esp
c0024132:	89 c3                	mov    %eax,%ebx
c0024134:	89 d6                	mov    %edx,%esi
c0024136:	89 4c 24 0c          	mov    %ecx,0xc(%esp)
  if (sector >= block_size (block))
c002413a:	50                   	push   %eax
c002413b:	e8 74 fe ff ff       	call   c0023fb4 <block_size>
c0024140:	83 c4 10             	add    $0x10,%esp
c0024143:	39 f0                	cmp    %esi,%eax
c0024145:	76 6b                	jbe    c00241b2 <read_partition_table+0x8a>
  pt = malloc (sizeof *pt);
c0024147:	83 ec 0c             	sub    $0xc,%esp
c002414a:	68 00 02 00 00       	push   $0x200
c002414f:	e8 2e ed ff ff       	call   c0022e82 <malloc>
c0024154:	89 c7                	mov    %eax,%edi
  if (pt == NULL)
c0024156:	83 c4 10             	add    $0x10,%esp
c0024159:	85 c0                	test   %eax,%eax
c002415b:	74 72                	je     c00241cf <read_partition_table+0xa7>
  block_read (block, 0, pt);
c002415d:	83 ec 04             	sub    $0x4,%esp
c0024160:	50                   	push   %eax
c0024161:	6a 00                	push   $0x0
c0024163:	53                   	push   %ebx
c0024164:	e8 bb fd ff ff       	call   c0023f24 <block_read>
  if (pt->signature != 0xaa55)
c0024169:	83 c4 10             	add    $0x10,%esp
c002416c:	66 81 bf fe 01 00 00 	cmpw   $0xaa55,0x1fe(%edi)
c0024173:	55 aa 
c0024175:	0f 84 87 00 00 00    	je     c0024202 <read_partition_table+0xda>
      if (primary_extended_sector == 0)
c002417b:	83 3c 24 00          	cmpl   $0x0,(%esp)
c002417f:	75 64                	jne    c00241e5 <read_partition_table+0xbd>
        printf ("%s: Invalid partition table signature\n", block_name (block));
c0024181:	83 ec 0c             	sub    $0xc,%esp
c0024184:	53                   	push   %ebx
c0024185:	e8 32 fe ff ff       	call   c0023fbc <block_name>
c002418a:	83 c4 08             	add    $0x8,%esp
c002418d:	50                   	push   %eax
c002418e:	68 78 e0 02 c0       	push   $0xc002e078
c0024193:	e8 c9 1b 00 00       	call   c0025d61 <printf>
c0024198:	83 c4 10             	add    $0x10,%esp
      free (pt);
c002419b:	83 ec 0c             	sub    $0xc,%esp
c002419e:	57                   	push   %edi
c002419f:	e8 7f ee ff ff       	call   c0023023 <free>
      return;
c00241a4:	83 c4 10             	add    $0x10,%esp
}
c00241a7:	81 c4 bc 00 00 00    	add    $0xbc,%esp
c00241ad:	5b                   	pop    %ebx
c00241ae:	5e                   	pop    %esi
c00241af:	5f                   	pop    %edi
c00241b0:	5d                   	pop    %ebp
c00241b1:	c3                   	ret    
      printf ("%s: Partition table at sector %"PRDSNu" past end of device.\n",
c00241b2:	83 ec 0c             	sub    $0xc,%esp
c00241b5:	53                   	push   %ebx
c00241b6:	e8 01 fe ff ff       	call   c0023fbc <block_name>
c00241bb:	83 c4 0c             	add    $0xc,%esp
c00241be:	56                   	push   %esi
c00241bf:	50                   	push   %eax
c00241c0:	68 10 e0 02 c0       	push   $0xc002e010
c00241c5:	e8 97 1b 00 00       	call   c0025d61 <printf>
      return;
c00241ca:	83 c4 10             	add    $0x10,%esp
c00241cd:	eb d8                	jmp    c00241a7 <read_partition_table+0x7f>
    PANIC ("Failed to allocate memory for partition table.");
c00241cf:	68 48 e0 02 c0       	push   $0xc002e048
c00241d4:	68 b0 bf 02 c0       	push   $0xc002bfb0
c00241d9:	6a 5a                	push   $0x5a
c00241db:	68 7f db 02 c0       	push   $0xc002db7f
c00241e0:	e8 2a 36 00 00       	call   c002780f <debug_panic>
        printf ("%s: Invalid extended partition table in sector %"PRDSNu"\n",
c00241e5:	83 ec 0c             	sub    $0xc,%esp
c00241e8:	53                   	push   %ebx
c00241e9:	e8 ce fd ff ff       	call   c0023fbc <block_name>
c00241ee:	83 c4 0c             	add    $0xc,%esp
c00241f1:	56                   	push   %esi
c00241f2:	50                   	push   %eax
c00241f3:	68 a0 e0 02 c0       	push   $0xc002e0a0
c00241f8:	e8 64 1b 00 00       	call   c0025d61 <printf>
c00241fd:	83 c4 10             	add    $0x10,%esp
c0024200:	eb 99                	jmp    c002419b <read_partition_table+0x73>
c0024202:	8d af c2 01 00 00    	lea    0x1c2(%edi),%ebp
c0024208:	8d 87 02 02 00 00    	lea    0x202(%edi),%eax
c002420e:	89 44 24 04          	mov    %eax,0x4(%esp)
      snprintf (extra_info, sizeof extra_info, "%s (%02x)",
c0024212:	89 7c 24 0c          	mov    %edi,0xc(%esp)
c0024216:	89 5c 24 08          	mov    %ebx,0x8(%esp)
c002421a:	89 74 24 10          	mov    %esi,0x10(%esp)
c002421e:	eb 51                	jmp    c0024271 <read_partition_table+0x149>
          printf ("%s: Extended partition in sector %"PRDSNu"\n",
c0024220:	83 ec 0c             	sub    $0xc,%esp
c0024223:	8b 5c 24 14          	mov    0x14(%esp),%ebx
c0024227:	53                   	push   %ebx
c0024228:	e8 8f fd ff ff       	call   c0023fbc <block_name>
c002422d:	83 c4 0c             	add    $0xc,%esp
c0024230:	8b 74 24 14          	mov    0x14(%esp),%esi
c0024234:	56                   	push   %esi
c0024235:	50                   	push   %eax
c0024236:	68 d4 e0 02 c0       	push   $0xc002e0d4
c002423b:	e8 21 1b 00 00       	call   c0025d61 <printf>
          if (sector == 0)
c0024240:	83 c4 10             	add    $0x10,%esp
c0024243:	85 f6                	test   %esi,%esi
c0024245:	0f 85 33 01 00 00    	jne    c002437e <read_partition_table+0x256>
            read_partition_table (block, e->offset, e->offset, part_nr);
c002424b:	8b 57 04             	mov    0x4(%edi),%edx
c002424e:	83 ec 0c             	sub    $0xc,%esp
c0024251:	ff b4 24 dc 00 00 00 	pushl  0xdc(%esp)
c0024258:	89 d1                	mov    %edx,%ecx
c002425a:	89 d8                	mov    %ebx,%eax
c002425c:	e8 c7 fe ff ff       	call   c0024128 <read_partition_table>
c0024261:	83 c4 10             	add    $0x10,%esp
c0024264:	83 c5 10             	add    $0x10,%ebp
  for (i = 0; i < sizeof pt->partitions / sizeof *pt->partitions; i++)
c0024267:	3b 6c 24 04          	cmp    0x4(%esp),%ebp
c002426b:	0f 84 b1 01 00 00    	je     c0024422 <read_partition_table+0x2fa>
c0024271:	89 ef                	mov    %ebp,%edi
      if (e->size == 0 || e->type == 0)
c0024273:	8b 75 08             	mov    0x8(%ebp),%esi
c0024276:	85 f6                	test   %esi,%esi
c0024278:	74 ea                	je     c0024264 <read_partition_table+0x13c>
c002427a:	8a 5d 00             	mov    0x0(%ebp),%bl
c002427d:	84 db                	test   %bl,%bl
c002427f:	74 e3                	je     c0024264 <read_partition_table+0x13c>
      else if (e->type == 0x05       /* Extended partition. */
c0024281:	88 d8                	mov    %bl,%al
c0024283:	83 e0 7f             	and    $0x7f,%eax
c0024286:	3c 05                	cmp    $0x5,%al
c0024288:	74 96                	je     c0024220 <read_partition_table+0xf8>
               || e->type == 0x0f    /* Windows 98 extended partition. */
c002428a:	80 fb 0f             	cmp    $0xf,%bl
c002428d:	74 91                	je     c0024220 <read_partition_table+0xf8>
               || e->type == 0xc5)   /* DR-DOS extended partition. */
c002428f:	80 fb c5             	cmp    $0xc5,%bl
c0024292:	74 8c                	je     c0024220 <read_partition_table+0xf8>
          ++*part_nr;
c0024294:	8b 84 24 d0 00 00 00 	mov    0xd0(%esp),%eax
c002429b:	8b 00                	mov    (%eax),%eax
c002429d:	40                   	inc    %eax
c002429e:	89 44 24 18          	mov    %eax,0x18(%esp)
c00242a2:	8b 94 24 d0 00 00 00 	mov    0xd0(%esp),%edx
c00242a9:	89 02                	mov    %eax,(%edx)
          found_partition (block, e->type, e->offset + sector,
c00242ab:	8b 44 24 10          	mov    0x10(%esp),%eax
c00242af:	03 45 04             	add    0x4(%ebp),%eax
c00242b2:	89 c7                	mov    %eax,%edi
c00242b4:	89 44 24 14          	mov    %eax,0x14(%esp)
  if (start >= block_size (block))
c00242b8:	83 ec 0c             	sub    $0xc,%esp
c00242bb:	ff 74 24 14          	pushl  0x14(%esp)
c00242bf:	e8 f0 fc ff ff       	call   c0023fb4 <block_size>
c00242c4:	83 c4 10             	add    $0x10,%esp
c00242c7:	39 c7                	cmp    %eax,%edi
c00242c9:	0f 83 d2 00 00 00    	jae    c00243a1 <read_partition_table+0x279>
  else if (start + size < start || start + size > block_size (block))
c00242cf:	8b 7c 24 14          	mov    0x14(%esp),%edi
c00242d3:	01 f7                	add    %esi,%edi
c00242d5:	0f 82 ed 00 00 00    	jb     c00243c8 <read_partition_table+0x2a0>
c00242db:	83 ec 0c             	sub    $0xc,%esp
c00242de:	ff 74 24 14          	pushl  0x14(%esp)
c00242e2:	e8 cd fc ff ff       	call   c0023fb4 <block_size>
c00242e7:	83 c4 10             	add    $0x10,%esp
c00242ea:	39 c7                	cmp    %eax,%edi
c00242ec:	0f 87 d6 00 00 00    	ja     c00243c8 <read_partition_table+0x2a0>
          found_partition (block, e->type, e->offset + sector,
c00242f2:	0f b6 fb             	movzbl %bl,%edi
                              : part_type == 0x21 ? BLOCK_FILESYS
c00242f5:	80 fb 20             	cmp    $0x20,%bl
c00242f8:	0f 84 39 01 00 00    	je     c0024437 <read_partition_table+0x30f>
c00242fe:	80 fb 21             	cmp    $0x21,%bl
c0024301:	0f 84 c2 01 00 00    	je     c00244c9 <read_partition_table+0x3a1>
c0024307:	80 fb 22             	cmp    $0x22,%bl
c002430a:	0f 84 c6 01 00 00    	je     c00244d6 <read_partition_table+0x3ae>
c0024310:	80 fb 23             	cmp    $0x23,%bl
c0024313:	0f 84 ca 01 00 00    	je     c00244e3 <read_partition_table+0x3bb>
      p = malloc (sizeof *p);
c0024319:	83 ec 0c             	sub    $0xc,%esp
c002431c:	6a 08                	push   $0x8
c002431e:	e8 5f eb ff ff       	call   c0022e82 <malloc>
c0024323:	89 c3                	mov    %eax,%ebx
      if (p == NULL)
c0024325:	83 c4 10             	add    $0x10,%esp
c0024328:	85 c0                	test   %eax,%eax
c002432a:	0f 84 ca 00 00 00    	je     c00243fa <read_partition_table+0x2d2>
      p->block = block;
c0024330:	8b 44 24 08          	mov    0x8(%esp),%eax
c0024334:	89 03                	mov    %eax,(%ebx)
      p->start = start;
c0024336:	8b 4c 24 14          	mov    0x14(%esp),%ecx
c002433a:	89 4b 04             	mov    %ecx,0x4(%ebx)
      snprintf (name, sizeof name, "%s%d", block_name (block), part_nr);
c002433d:	83 ec 0c             	sub    $0xc,%esp
c0024340:	50                   	push   %eax
c0024341:	e8 76 fc ff ff       	call   c0023fbc <block_name>
c0024346:	83 c4 04             	add    $0x4,%esp
c0024349:	ff 74 24 24          	pushl  0x24(%esp)
c002434d:	50                   	push   %eax
c002434e:	68 99 db 02 c0       	push   $0xc002db99
c0024353:	6a 10                	push   $0x10
c0024355:	8d 44 24 3c          	lea    0x3c(%esp),%eax
c0024359:	50                   	push   %eax
c002435a:	e8 8e 21 00 00       	call   c00264ed <snprintf>
  return type_names[type] != NULL ? type_names[type] : "Unknown";
c002435f:	8b 04 bd a0 bb 02 c0 	mov    -0x3ffd4460(,%edi,4),%eax
c0024366:	83 c4 20             	add    $0x20,%esp
c0024369:	85 c0                	test   %eax,%eax
c002436b:	0f 84 a2 00 00 00    	je     c0024413 <read_partition_table+0x2eb>
                              : part_type == 0x21 ? BLOCK_FILESYS
c0024371:	c7 44 24 1c 05 00 00 	movl   $0x5,0x1c(%esp)
c0024378:	00 
c0024379:	e9 0d 01 00 00       	jmp    c002448b <read_partition_table+0x363>
            read_partition_table (block, e->offset + primary_extended_sector,
c002437e:	8b 0c 24             	mov    (%esp),%ecx
c0024381:	89 ca                	mov    %ecx,%edx
c0024383:	03 57 04             	add    0x4(%edi),%edx
c0024386:	83 ec 0c             	sub    $0xc,%esp
c0024389:	ff b4 24 dc 00 00 00 	pushl  0xdc(%esp)
c0024390:	8b 44 24 18          	mov    0x18(%esp),%eax
c0024394:	e8 8f fd ff ff       	call   c0024128 <read_partition_table>
c0024399:	83 c4 10             	add    $0x10,%esp
c002439c:	e9 c3 fe ff ff       	jmp    c0024264 <read_partition_table+0x13c>
    printf ("%s%d: Partition starts past end of device (sector %"PRDSNu")\n",
c00243a1:	83 ec 0c             	sub    $0xc,%esp
c00243a4:	ff 74 24 14          	pushl  0x14(%esp)
c00243a8:	e8 0f fc ff ff       	call   c0023fbc <block_name>
c00243ad:	ff 74 24 24          	pushl  0x24(%esp)
c00243b1:	ff 74 24 2c          	pushl  0x2c(%esp)
c00243b5:	50                   	push   %eax
c00243b6:	68 fc e0 02 c0       	push   $0xc002e0fc
c00243bb:	e8 a1 19 00 00       	call   c0025d61 <printf>
c00243c0:	83 c4 20             	add    $0x20,%esp
c00243c3:	e9 9c fe ff ff       	jmp    c0024264 <read_partition_table+0x13c>
    printf ("%s%d: Partition end (%"PRDSNu") past end of device (%"PRDSNu")\n",
c00243c8:	83 ec 0c             	sub    $0xc,%esp
c00243cb:	8b 74 24 14          	mov    0x14(%esp),%esi
c00243cf:	56                   	push   %esi
c00243d0:	e8 df fb ff ff       	call   c0023fb4 <block_size>
c00243d5:	89 c3                	mov    %eax,%ebx
c00243d7:	89 34 24             	mov    %esi,(%esp)
c00243da:	e8 dd fb ff ff       	call   c0023fbc <block_name>
c00243df:	89 1c 24             	mov    %ebx,(%esp)
c00243e2:	57                   	push   %edi
c00243e3:	ff 74 24 2c          	pushl  0x2c(%esp)
c00243e7:	50                   	push   %eax
c00243e8:	68 34 e1 02 c0       	push   $0xc002e134
c00243ed:	e8 6f 19 00 00       	call   c0025d61 <printf>
c00243f2:	83 c4 20             	add    $0x20,%esp
c00243f5:	e9 6a fe ff ff       	jmp    c0024264 <read_partition_table+0x13c>
        PANIC ("Failed to allocate memory for partition descriptor");
c00243fa:	68 68 e1 02 c0       	push   $0xc002e168
c00243ff:	68 a0 bf 02 c0       	push   $0xc002bfa0
c0024404:	68 b1 00 00 00       	push   $0xb1
c0024409:	68 7f db 02 c0       	push   $0xc002db7f
c002440e:	e8 fc 33 00 00       	call   c002780f <debug_panic>
                              : part_type == 0x21 ? BLOCK_FILESYS
c0024413:	c7 44 24 1c 05 00 00 	movl   $0x5,0x1c(%esp)
c002441a:	00 
  return type_names[type] != NULL ? type_names[type] : "Unknown";
c002441b:	b8 77 db 02 c0       	mov    $0xc002db77,%eax
c0024420:	eb 69                	jmp    c002448b <read_partition_table+0x363>
c0024422:	8b 7c 24 0c          	mov    0xc(%esp),%edi
  free (pt);
c0024426:	83 ec 0c             	sub    $0xc,%esp
c0024429:	57                   	push   %edi
c002442a:	e8 f4 eb ff ff       	call   c0023023 <free>
c002442f:	83 c4 10             	add    $0x10,%esp
c0024432:	e9 70 fd ff ff       	jmp    c00241a7 <read_partition_table+0x7f>
                              : part_type == 0x21 ? BLOCK_FILESYS
c0024437:	c7 44 24 1c 00 00 00 	movl   $0x0,0x1c(%esp)
c002443e:	00 
      p = malloc (sizeof *p);
c002443f:	83 ec 0c             	sub    $0xc,%esp
c0024442:	6a 08                	push   $0x8
c0024444:	e8 39 ea ff ff       	call   c0022e82 <malloc>
c0024449:	89 c3                	mov    %eax,%ebx
      if (p == NULL)
c002444b:	83 c4 10             	add    $0x10,%esp
c002444e:	85 c0                	test   %eax,%eax
c0024450:	74 a8                	je     c00243fa <read_partition_table+0x2d2>
      p->block = block;
c0024452:	8b 44 24 08          	mov    0x8(%esp),%eax
c0024456:	89 03                	mov    %eax,(%ebx)
      p->start = start;
c0024458:	8b 4c 24 14          	mov    0x14(%esp),%ecx
c002445c:	89 4b 04             	mov    %ecx,0x4(%ebx)
      snprintf (name, sizeof name, "%s%d", block_name (block), part_nr);
c002445f:	83 ec 0c             	sub    $0xc,%esp
c0024462:	50                   	push   %eax
c0024463:	e8 54 fb ff ff       	call   c0023fbc <block_name>
c0024468:	83 c4 04             	add    $0x4,%esp
c002446b:	ff 74 24 24          	pushl  0x24(%esp)
c002446f:	50                   	push   %eax
c0024470:	68 99 db 02 c0       	push   $0xc002db99
c0024475:	6a 10                	push   $0x10
c0024477:	8d 44 24 3c          	lea    0x3c(%esp),%eax
c002447b:	50                   	push   %eax
c002447c:	e8 6c 20 00 00       	call   c00264ed <snprintf>
  return type_names[type] != NULL ? type_names[type] : "Unknown";
c0024481:	8b 04 bd a0 bb 02 c0 	mov    -0x3ffd4460(,%edi,4),%eax
c0024488:	83 c4 20             	add    $0x20,%esp
      snprintf (extra_info, sizeof extra_info, "%s (%02x)",
c002448b:	83 ec 0c             	sub    $0xc,%esp
c002448e:	57                   	push   %edi
c002448f:	50                   	push   %eax
c0024490:	68 9e db 02 c0       	push   $0xc002db9e
c0024495:	68 80 00 00 00       	push   $0x80
c002449a:	8d 44 24 4c          	lea    0x4c(%esp),%eax
c002449e:	50                   	push   %eax
c002449f:	e8 49 20 00 00       	call   c00264ed <snprintf>
      block_register (name, type, extra_info, size, &partition_operations, p);
c00244a4:	83 c4 18             	add    $0x18,%esp
c00244a7:	53                   	push   %ebx
c00244a8:	68 dc 68 03 c0       	push   $0xc00368dc
c00244ad:	56                   	push   %esi
c00244ae:	8d 44 24 44          	lea    0x44(%esp),%eax
c00244b2:	50                   	push   %eax
c00244b3:	ff 74 24 34          	pushl  0x34(%esp)
c00244b7:	8d 44 24 3c          	lea    0x3c(%esp),%eax
c00244bb:	50                   	push   %eax
c00244bc:	e8 59 fb ff ff       	call   c002401a <block_register>
c00244c1:	83 c4 20             	add    $0x20,%esp
c00244c4:	e9 9b fd ff ff       	jmp    c0024264 <read_partition_table+0x13c>
                              : part_type == 0x21 ? BLOCK_FILESYS
c00244c9:	c7 44 24 1c 01 00 00 	movl   $0x1,0x1c(%esp)
c00244d0:	00 
c00244d1:	e9 69 ff ff ff       	jmp    c002443f <read_partition_table+0x317>
c00244d6:	c7 44 24 1c 02 00 00 	movl   $0x2,0x1c(%esp)
c00244dd:	00 
c00244de:	e9 5c ff ff ff       	jmp    c002443f <read_partition_table+0x317>
c00244e3:	c7 44 24 1c 03 00 00 	movl   $0x3,0x1c(%esp)
c00244ea:	00 
c00244eb:	e9 4f ff ff ff       	jmp    c002443f <read_partition_table+0x317>

c00244f0 <partition_write>:
/* Write sector SECTOR to partition P from BUFFER, which must
   contain BLOCK_SECTOR_SIZE bytes.  Returns after the block has
   acknowledged receiving the data. */
static void
partition_write (void *p_, block_sector_t sector, const void *buffer)
{
c00244f0:	83 ec 10             	sub    $0x10,%esp
c00244f3:	8b 54 24 14          	mov    0x14(%esp),%edx
  struct partition *p = p_;
  block_write (p->block, p->start + sector, buffer);
c00244f7:	ff 74 24 1c          	pushl  0x1c(%esp)
c00244fb:	8b 42 04             	mov    0x4(%edx),%eax
c00244fe:	03 44 24 1c          	add    0x1c(%esp),%eax
c0024502:	50                   	push   %eax
c0024503:	ff 32                	pushl  (%edx)
c0024505:	e8 4e fa ff ff       	call   c0023f58 <block_write>
}
c002450a:	83 c4 1c             	add    $0x1c,%esp
c002450d:	c3                   	ret    

c002450e <partition_scan>:
{
c002450e:	83 ec 28             	sub    $0x28,%esp
  int part_nr = 0;
c0024511:	c7 44 24 18 00 00 00 	movl   $0x0,0x18(%esp)
c0024518:	00 
  read_partition_table (block, 0, 0, &part_nr);
c0024519:	8d 44 24 18          	lea    0x18(%esp),%eax
c002451d:	50                   	push   %eax
c002451e:	b9 00 00 00 00       	mov    $0x0,%ecx
c0024523:	ba 00 00 00 00       	mov    $0x0,%edx
c0024528:	8b 44 24 30          	mov    0x30(%esp),%eax
c002452c:	e8 f7 fb ff ff       	call   c0024128 <read_partition_table>
  if (part_nr == 0)
c0024531:	83 c4 10             	add    $0x10,%esp
c0024534:	83 7c 24 0c 00       	cmpl   $0x0,0xc(%esp)
c0024539:	74 04                	je     c002453f <partition_scan+0x31>
}
c002453b:	83 c4 1c             	add    $0x1c,%esp
c002453e:	c3                   	ret    
    printf ("%s: Device contains no partitions\n", block_name (block));
c002453f:	83 ec 0c             	sub    $0xc,%esp
c0024542:	ff 74 24 2c          	pushl  0x2c(%esp)
c0024546:	e8 71 fa ff ff       	call   c0023fbc <block_name>
c002454b:	83 c4 08             	add    $0x8,%esp
c002454e:	50                   	push   %eax
c002454f:	68 9c e1 02 c0       	push   $0xc002e19c
c0024554:	e8 08 18 00 00       	call   c0025d61 <printf>
c0024559:	83 c4 10             	add    $0x10,%esp
}
c002455c:	eb dd                	jmp    c002453b <partition_scan+0x2d>

c002455e <descramble_ata_string>:
/* Translates STRING, which consists of SIZE bytes in a funky
   format, into a null-terminated string in-place.  Drops
   trailing whitespace and null bytes.  Returns STRING.  */
static char *
descramble_ata_string (char *string, int size) 
{
c002455e:	57                   	push   %edi
c002455f:	56                   	push   %esi
c0024560:	53                   	push   %ebx
c0024561:	89 d7                	mov    %edx,%edi
  int i;

  /* Swap all pairs of bytes. */
  for (i = 0; i + 1 < size; i += 2)
c0024563:	83 fa 01             	cmp    $0x1,%edx
c0024566:	7e 1d                	jle    c0024585 <descramble_ata_string+0x27>
c0024568:	89 c1                	mov    %eax,%ecx
c002456a:	8d 5a fe             	lea    -0x2(%edx),%ebx
c002456d:	83 e3 fe             	and    $0xfffffffe,%ebx
c0024570:	8d 74 18 02          	lea    0x2(%eax,%ebx,1),%esi
    {
      char tmp = string[i];
c0024574:	8a 19                	mov    (%ecx),%bl
      string[i] = string[i + 1];
c0024576:	8a 51 01             	mov    0x1(%ecx),%dl
c0024579:	88 11                	mov    %dl,(%ecx)
      string[i + 1] = tmp;
c002457b:	88 59 01             	mov    %bl,0x1(%ecx)
c002457e:	83 c1 02             	add    $0x2,%ecx
  for (i = 0; i + 1 < size; i += 2)
c0024581:	39 f1                	cmp    %esi,%ecx
c0024583:	75 ef                	jne    c0024574 <descramble_ata_string+0x16>
    }

  /* Find the last non-white, non-null character. */
  for (size--; size > 0; size--)
c0024585:	8d 57 ff             	lea    -0x1(%edi),%edx
c0024588:	85 d2                	test   %edx,%edx
c002458a:	7f 05                	jg     c0024591 <descramble_ata_string+0x33>
c002458c:	eb 14                	jmp    c00245a2 <descramble_ata_string+0x44>
c002458e:	4a                   	dec    %edx
c002458f:	74 11                	je     c00245a2 <descramble_ata_string+0x44>
    {
      int c = string[size - 1];
c0024591:	8a 4c 10 ff          	mov    -0x1(%eax,%edx,1),%cl
      if (c != '\0' && !isspace (c))
c0024595:	f6 c1 df             	test   $0xdf,%cl
c0024598:	74 f4                	je     c002458e <descramble_ata_string+0x30>
          || c == '\r' || c == '\t' || c == '\v');
c002459a:	83 e9 09             	sub    $0x9,%ecx
c002459d:	80 f9 04             	cmp    $0x4,%cl
c00245a0:	76 ec                	jbe    c002458e <descramble_ata_string+0x30>
        break; 
    }
  string[size] = '\0';
c00245a2:	c6 04 10 00          	movb   $0x0,(%eax,%edx,1)

  return string;
}
c00245a6:	5b                   	pop    %ebx
c00245a7:	5e                   	pop    %esi
c00245a8:	5f                   	pop    %edi
c00245a9:	c3                   	ret    

c00245aa <interrupt_handler>:
}

/* ATA interrupt handler. */
static void
interrupt_handler (struct intr_frame *f) 
{
c00245aa:	83 ec 0c             	sub    $0xc,%esp
  struct channel *c;

  for (c = channels; c < channels + CHANNEL_CNT; c++)
    if (f->vec_no == c->irq)
c00245ad:	8b 44 24 10          	mov    0x10(%esp),%eax
c00245b1:	8b 40 30             	mov    0x30(%eax),%eax
c00245b4:	0f b6 15 ca 81 03 c0 	movzbl 0xc00381ca,%edx
c00245bb:	39 d0                	cmp    %edx,%eax
c00245bd:	74 29                	je     c00245e8 <interrupt_handler+0x3e>
c00245bf:	0f b6 15 2e 82 03 c0 	movzbl 0xc003822e,%edx
c00245c6:	b9 24 82 03 c0       	mov    $0xc0038224,%ecx
c00245cb:	39 c2                	cmp    %eax,%edx
c00245cd:	74 1e                	je     c00245ed <interrupt_handler+0x43>
        else
          printf ("%s: unexpected interrupt\n", c->name);
        return;
      }

  NOT_REACHED ();
c00245cf:	68 4c d2 02 c0       	push   $0xc002d24c
c00245d4:	68 18 c0 02 c0       	push   $0xc002c018
c00245d9:	68 0c 02 00 00       	push   $0x20c
c00245de:	68 d9 e1 02 c0       	push   $0xc002e1d9
c00245e3:	e8 27 32 00 00       	call   c002780f <debug_panic>
  for (c = channels; c < channels + CHANNEL_CNT; c++)
c00245e8:	b9 c0 81 03 c0       	mov    $0xc00381c0,%ecx
        if (c->expecting_interrupt) 
c00245ed:	80 79 24 00          	cmpb   $0x0,0x24(%ecx)
c00245f1:	74 1a                	je     c002460d <interrupt_handler+0x63>
            inb (reg_status (c));               /* Acknowledge interrupt. */
c00245f3:	8b 41 08             	mov    0x8(%ecx),%eax
c00245f6:	8d 50 07             	lea    0x7(%eax),%edx
  asm volatile ("inb %w1, %b0" : "=a" (data) : "Nd" (port));
c00245f9:	ec                   	in     (%dx),%al
            sema_up (&c->completion_wait);      /* Wake up waiter. */
c00245fa:	83 ec 0c             	sub    $0xc,%esp
c00245fd:	83 c1 28             	add    $0x28,%ecx
c0024600:	51                   	push   %ecx
c0024601:	e8 9c dd ff ff       	call   c00223a2 <sema_up>
c0024606:	83 c4 10             	add    $0x10,%esp
}
c0024609:	83 c4 0c             	add    $0xc,%esp
c002460c:	c3                   	ret    
          printf ("%s: unexpected interrupt\n", c->name);
c002460d:	83 ec 08             	sub    $0x8,%esp
c0024610:	51                   	push   %ecx
c0024611:	68 bf e1 02 c0       	push   $0xc002e1bf
c0024616:	e8 46 17 00 00       	call   c0025d61 <printf>
c002461b:	83 c4 10             	add    $0x10,%esp
c002461e:	eb e9                	jmp    c0024609 <interrupt_handler+0x5f>

c0024620 <wait_until_idle>:
{
c0024620:	56                   	push   %esi
c0024621:	53                   	push   %ebx
c0024622:	83 ec 04             	sub    $0x4,%esp
c0024625:	89 c6                	mov    %eax,%esi
      if ((inb (reg_status (d->channel)) & (STA_BSY | STA_DRQ)) == 0)
c0024627:	8b 40 08             	mov    0x8(%eax),%eax
c002462a:	8b 40 08             	mov    0x8(%eax),%eax
c002462d:	8d 50 07             	lea    0x7(%eax),%edx
c0024630:	ec                   	in     (%dx),%al
c0024631:	a8 88                	test   $0x88,%al
c0024633:	74 45                	je     c002467a <wait_until_idle+0x5a>
      timer_usleep (10);
c0024635:	83 ec 08             	sub    $0x8,%esp
c0024638:	6a 00                	push   $0x0
c002463a:	6a 0a                	push   $0xa
c002463c:	e8 5c ef ff ff       	call   c002359d <timer_usleep>
c0024641:	83 c4 10             	add    $0x10,%esp
c0024644:	bb e7 03 00 00       	mov    $0x3e7,%ebx
      if ((inb (reg_status (d->channel)) & (STA_BSY | STA_DRQ)) == 0)
c0024649:	8b 46 08             	mov    0x8(%esi),%eax
c002464c:	8b 40 08             	mov    0x8(%eax),%eax
c002464f:	8d 50 07             	lea    0x7(%eax),%edx
c0024652:	ec                   	in     (%dx),%al
c0024653:	a8 88                	test   $0x88,%al
c0024655:	74 23                	je     c002467a <wait_until_idle+0x5a>
      timer_usleep (10);
c0024657:	83 ec 08             	sub    $0x8,%esp
c002465a:	6a 00                	push   $0x0
c002465c:	6a 0a                	push   $0xa
c002465e:	e8 3a ef ff ff       	call   c002359d <timer_usleep>
  for (i = 0; i < 1000; i++) 
c0024663:	83 c4 10             	add    $0x10,%esp
c0024666:	4b                   	dec    %ebx
c0024667:	75 e0                	jne    c0024649 <wait_until_idle+0x29>
  printf ("%s: idle timeout\n", d->name);
c0024669:	83 ec 08             	sub    $0x8,%esp
c002466c:	56                   	push   %esi
c002466d:	68 ed e1 02 c0       	push   $0xc002e1ed
c0024672:	e8 ea 16 00 00       	call   c0025d61 <printf>
c0024677:	83 c4 10             	add    $0x10,%esp
}
c002467a:	83 c4 04             	add    $0x4,%esp
c002467d:	5b                   	pop    %ebx
c002467e:	5e                   	pop    %esi
c002467f:	c3                   	ret    

c0024680 <select_device>:
{
c0024680:	83 ec 0c             	sub    $0xc,%esp
  struct channel *c = d->channel;
c0024683:	8b 50 08             	mov    0x8(%eax),%edx
  if (d->dev_no == 1)
c0024686:	83 78 0c 01          	cmpl   $0x1,0xc(%eax)
c002468a:	74 23                	je     c00246af <select_device+0x2f>
  uint8_t dev = DEV_MBS;
c002468c:	b0 a0                	mov    $0xa0,%al
  outb (reg_device (c), dev);
c002468e:	8b 4a 08             	mov    0x8(%edx),%ecx
c0024691:	8d 51 06             	lea    0x6(%ecx),%edx
  asm volatile ("outb %b0, %w1" : : "a" (data), "Nd" (port));
c0024694:	ee                   	out    %al,(%dx)
  inb (reg_alt_status (c));
c0024695:	8d 91 06 02 00 00    	lea    0x206(%ecx),%edx
  asm volatile ("inb %w1, %b0" : "=a" (data) : "Nd" (port));
c002469b:	ec                   	in     (%dx),%al
  timer_nsleep (400);
c002469c:	83 ec 08             	sub    $0x8,%esp
c002469f:	6a 00                	push   $0x0
c00246a1:	68 90 01 00 00       	push   $0x190
c00246a6:	e8 0b ef ff ff       	call   c00235b6 <timer_nsleep>
}
c00246ab:	83 c4 1c             	add    $0x1c,%esp
c00246ae:	c3                   	ret    
    dev |= DEV_DEV;
c00246af:	b0 b0                	mov    $0xb0,%al
c00246b1:	eb db                	jmp    c002468e <select_device+0xe>

c00246b3 <check_device_type>:
{
c00246b3:	56                   	push   %esi
c00246b4:	53                   	push   %ebx
c00246b5:	83 ec 14             	sub    $0x14,%esp
c00246b8:	89 c6                	mov    %eax,%esi
  struct channel *c = d->channel;
c00246ba:	8b 58 08             	mov    0x8(%eax),%ebx
  select_device (d);
c00246bd:	e8 be ff ff ff       	call   c0024680 <select_device>
  error = inb (reg_error (c));
c00246c2:	8b 5b 08             	mov    0x8(%ebx),%ebx
c00246c5:	8d 53 01             	lea    0x1(%ebx),%edx
c00246c8:	ec                   	in     (%dx),%al
c00246c9:	88 c1                	mov    %al,%cl
  lbam = inb (reg_lbam (c));
c00246cb:	8d 53 04             	lea    0x4(%ebx),%edx
c00246ce:	ec                   	in     (%dx),%al
c00246cf:	88 44 24 0e          	mov    %al,0xe(%esp)
  lbah = inb (reg_lbah (c));
c00246d3:	8d 53 05             	lea    0x5(%ebx),%edx
c00246d6:	ec                   	in     (%dx),%al
c00246d7:	88 44 24 0f          	mov    %al,0xf(%esp)
  status = inb (reg_status (c));
c00246db:	8d 53 07             	lea    0x7(%ebx),%edx
c00246de:	ec                   	in     (%dx),%al
  if ((error != 1 && (error != 0x81 || d->dev_no == 1))
c00246df:	80 f9 01             	cmp    $0x1,%cl
c00246e2:	74 1b                	je     c00246ff <check_device_type+0x4c>
c00246e4:	80 f9 81             	cmp    $0x81,%cl
c00246e7:	74 10                	je     c00246f9 <check_device_type+0x46>
      d->is_ata = false;
c00246e9:	c6 46 10 00          	movb   $0x0,0x10(%esi)
      return error != 0x81;      
c00246ed:	80 f9 81             	cmp    $0x81,%cl
c00246f0:	0f 95 c0             	setne  %al
}
c00246f3:	83 c4 14             	add    $0x14,%esp
c00246f6:	5b                   	pop    %ebx
c00246f7:	5e                   	pop    %esi
c00246f8:	c3                   	ret    
  if ((error != 1 && (error != 0x81 || d->dev_no == 1))
c00246f9:	83 7e 0c 01          	cmpl   $0x1,0xc(%esi)
c00246fd:	74 ea                	je     c00246e9 <check_device_type+0x36>
      || (status & STA_DRDY) == 0
c00246ff:	a8 40                	test   $0x40,%al
c0024701:	74 e6                	je     c00246e9 <check_device_type+0x36>
      || (status & STA_BSY) != 0)
c0024703:	84 c0                	test   %al,%al
c0024705:	78 e2                	js     c00246e9 <check_device_type+0x36>
      d->is_ata = (lbam == 0 && lbah == 0) || (lbam == 0x3c && lbah == 0xc3);
c0024707:	80 7c 24 0e 00       	cmpb   $0x0,0xe(%esp)
c002470c:	75 16                	jne    c0024724 <check_device_type+0x71>
c002470e:	80 7c 24 0f 00       	cmpb   $0x0,0xf(%esp)
c0024713:	0f 94 c0             	sete   %al
c0024716:	0f b6 c0             	movzbl %al,%eax
c0024719:	88 46 10             	mov    %al,0x10(%esi)
c002471c:	80 66 10 01          	andb   $0x1,0x10(%esi)
      return true; 
c0024720:	b0 01                	mov    $0x1,%al
c0024722:	eb cf                	jmp    c00246f3 <check_device_type+0x40>
      d->is_ata = (lbam == 0 && lbah == 0) || (lbam == 0x3c && lbah == 0xc3);
c0024724:	80 7c 24 0e 3c       	cmpb   $0x3c,0xe(%esp)
c0024729:	74 07                	je     c0024732 <check_device_type+0x7f>
c002472b:	b8 00 00 00 00       	mov    $0x0,%eax
c0024730:	eb e7                	jmp    c0024719 <check_device_type+0x66>
c0024732:	80 7c 24 0f c3       	cmpb   $0xc3,0xf(%esp)
c0024737:	0f 94 c0             	sete   %al
c002473a:	0f b6 c0             	movzbl %al,%eax
c002473d:	eb da                	jmp    c0024719 <check_device_type+0x66>

c002473f <select_sector>:
{
c002473f:	57                   	push   %edi
c0024740:	56                   	push   %esi
c0024741:	53                   	push   %ebx
  struct channel *c = d->channel;
c0024742:	8b 78 08             	mov    0x8(%eax),%edi
  ASSERT (sec_no < (1UL << 28));
c0024745:	81 fa ff ff ff 0f    	cmp    $0xfffffff,%edx
c002474b:	77 4d                	ja     c002479a <select_sector+0x5b>
c002474d:	89 c6                	mov    %eax,%esi
c002474f:	89 d3                	mov    %edx,%ebx
  wait_until_idle (d);
c0024751:	e8 ca fe ff ff       	call   c0024620 <wait_until_idle>
  select_device (d);
c0024756:	89 f0                	mov    %esi,%eax
c0024758:	e8 23 ff ff ff       	call   c0024680 <select_device>
  wait_until_idle (d);
c002475d:	89 f0                	mov    %esi,%eax
c002475f:	e8 bc fe ff ff       	call   c0024620 <wait_until_idle>
  outb (reg_nsect (c), 1);
c0024764:	8b 4f 08             	mov    0x8(%edi),%ecx
c0024767:	8d 51 02             	lea    0x2(%ecx),%edx
  asm volatile ("outb %b0, %w1" : : "a" (data), "Nd" (port));
c002476a:	b0 01                	mov    $0x1,%al
c002476c:	ee                   	out    %al,(%dx)
  outb (reg_lbal (c), sec_no);
c002476d:	8d 51 03             	lea    0x3(%ecx),%edx
c0024770:	88 d8                	mov    %bl,%al
c0024772:	ee                   	out    %al,(%dx)
  outb (reg_lbam (c), sec_no >> 8);
c0024773:	89 d8                	mov    %ebx,%eax
c0024775:	c1 e8 08             	shr    $0x8,%eax
c0024778:	8d 51 04             	lea    0x4(%ecx),%edx
c002477b:	ee                   	out    %al,(%dx)
  outb (reg_lbah (c), (sec_no >> 16));
c002477c:	89 d8                	mov    %ebx,%eax
c002477e:	c1 e8 10             	shr    $0x10,%eax
c0024781:	8d 51 05             	lea    0x5(%ecx),%edx
c0024784:	ee                   	out    %al,(%dx)
        DEV_MBS | DEV_LBA | (d->dev_no == 1 ? DEV_DEV : 0) | (sec_no >> 24));
c0024785:	83 7e 0c 01          	cmpl   $0x1,0xc(%esi)
c0024789:	74 30                	je     c00247bb <select_sector+0x7c>
c002478b:	b0 e0                	mov    $0xe0,%al
c002478d:	c1 eb 18             	shr    $0x18,%ebx
c0024790:	09 d8                	or     %ebx,%eax
  outb (reg_device (c),
c0024792:	8d 51 06             	lea    0x6(%ecx),%edx
c0024795:	ee                   	out    %al,(%dx)
}
c0024796:	5b                   	pop    %ebx
c0024797:	5e                   	pop    %esi
c0024798:	5f                   	pop    %edi
c0024799:	c3                   	ret    
  ASSERT (sec_no < (1UL << 28));
c002479a:	83 ec 0c             	sub    $0xc,%esp
c002479d:	68 ff e1 02 c0       	push   $0xc002e1ff
c00247a2:	68 9f cd 02 c0       	push   $0xc002cd9f
c00247a7:	68 e8 bf 02 c0       	push   $0xc002bfe8
c00247ac:	68 89 01 00 00       	push   $0x189
c00247b1:	68 d9 e1 02 c0       	push   $0xc002e1d9
c00247b6:	e8 54 30 00 00       	call   c002780f <debug_panic>
        DEV_MBS | DEV_LBA | (d->dev_no == 1 ? DEV_DEV : 0) | (sec_no >> 24));
c00247bb:	b0 f0                	mov    $0xf0,%al
c00247bd:	eb ce                	jmp    c002478d <select_sector+0x4e>

c00247bf <wait_while_busy>:
{
c00247bf:	57                   	push   %edi
c00247c0:	56                   	push   %esi
c00247c1:	53                   	push   %ebx
c00247c2:	89 c7                	mov    %eax,%edi
  struct channel *c = d->channel;
c00247c4:	8b 70 08             	mov    0x8(%eax),%esi
  for (i = 0; i < 3000; i++)
c00247c7:	bb 00 00 00 00       	mov    $0x0,%ebx
      if (!(inb (reg_alt_status (c)) & STA_BSY)) 
c00247cc:	8b 46 08             	mov    0x8(%esi),%eax
c00247cf:	8d 90 06 02 00 00    	lea    0x206(%eax),%edx
  asm volatile ("inb %w1, %b0" : "=a" (data) : "Nd" (port));
c00247d5:	ec                   	in     (%dx),%al
c00247d6:	84 c0                	test   %al,%al
c00247d8:	79 33                	jns    c002480d <wait_while_busy+0x4e>
      timer_msleep (10);
c00247da:	83 ec 08             	sub    $0x8,%esp
c00247dd:	6a 00                	push   $0x0
c00247df:	6a 0a                	push   $0xa
c00247e1:	e8 9e ed ff ff       	call   c0023584 <timer_msleep>
  for (i = 0; i < 3000; i++)
c00247e6:	43                   	inc    %ebx
c00247e7:	83 c4 10             	add    $0x10,%esp
c00247ea:	81 fb b8 0b 00 00    	cmp    $0xbb8,%ebx
c00247f0:	74 49                	je     c002483b <wait_while_busy+0x7c>
      if (i == 700)
c00247f2:	81 fb bc 02 00 00    	cmp    $0x2bc,%ebx
c00247f8:	75 d2                	jne    c00247cc <wait_while_busy+0xd>
        printf ("%s: busy, waiting...", d->name);
c00247fa:	83 ec 08             	sub    $0x8,%esp
c00247fd:	57                   	push   %edi
c00247fe:	68 14 e2 02 c0       	push   $0xc002e214
c0024803:	e8 59 15 00 00       	call   c0025d61 <printf>
c0024808:	83 c4 10             	add    $0x10,%esp
c002480b:	eb bf                	jmp    c00247cc <wait_while_busy+0xd>
          if (i >= 700)
c002480d:	81 fb bb 02 00 00    	cmp    $0x2bb,%ebx
c0024813:	7f 14                	jg     c0024829 <wait_while_busy+0x6a>
          return (inb (reg_alt_status (c)) & STA_DRQ) != 0;
c0024815:	8b 46 08             	mov    0x8(%esi),%eax
c0024818:	8d 90 06 02 00 00    	lea    0x206(%eax),%edx
c002481e:	ec                   	in     (%dx),%al
c002481f:	c0 e8 03             	shr    $0x3,%al
c0024822:	83 e0 01             	and    $0x1,%eax
}
c0024825:	5b                   	pop    %ebx
c0024826:	5e                   	pop    %esi
c0024827:	5f                   	pop    %edi
c0024828:	c3                   	ret    
            printf ("ok\n");
c0024829:	83 ec 0c             	sub    $0xc,%esp
c002482c:	68 29 e2 02 c0       	push   $0xc002e229
c0024831:	e8 27 4a 00 00       	call   c002925d <puts>
c0024836:	83 c4 10             	add    $0x10,%esp
c0024839:	eb da                	jmp    c0024815 <wait_while_busy+0x56>
  printf ("failed\n");
c002483b:	83 ec 0c             	sub    $0xc,%esp
c002483e:	68 c8 ea 02 c0       	push   $0xc002eac8
c0024843:	e8 15 4a 00 00       	call   c002925d <puts>
  return false;
c0024848:	83 c4 10             	add    $0x10,%esp
c002484b:	b0 00                	mov    $0x0,%al
c002484d:	eb d6                	jmp    c0024825 <wait_while_busy+0x66>

c002484f <issue_pio_command>:
{
c002484f:	56                   	push   %esi
c0024850:	53                   	push   %ebx
c0024851:	83 ec 04             	sub    $0x4,%esp
c0024854:	89 c3                	mov    %eax,%ebx
c0024856:	89 d6                	mov    %edx,%esi
  ASSERT (intr_get_level () == INTR_ON);
c0024858:	e8 ba c9 ff ff       	call   c0021217 <intr_get_level>
c002485d:	83 f8 01             	cmp    $0x1,%eax
c0024860:	75 13                	jne    c0024875 <issue_pio_command+0x26>
  c->expecting_interrupt = true;
c0024862:	c6 43 24 01          	movb   $0x1,0x24(%ebx)
  outb (reg_command (c), command);
c0024866:	8b 53 08             	mov    0x8(%ebx),%edx
c0024869:	83 c2 07             	add    $0x7,%edx
  asm volatile ("outb %b0, %w1" : : "a" (data), "Nd" (port));
c002486c:	89 f0                	mov    %esi,%eax
c002486e:	ee                   	out    %al,(%dx)
}
c002486f:	83 c4 04             	add    $0x4,%esp
c0024872:	5b                   	pop    %ebx
c0024873:	5e                   	pop    %esi
c0024874:	c3                   	ret    
  ASSERT (intr_get_level () == INTR_ON);
c0024875:	83 ec 0c             	sub    $0xc,%esp
c0024878:	68 36 d9 02 c0       	push   $0xc002d936
c002487d:	68 9f cd 02 c0       	push   $0xc002cd9f
c0024882:	68 c8 bf 02 c0       	push   $0xc002bfc8
c0024887:	68 9b 01 00 00       	push   $0x19b
c002488c:	68 d9 e1 02 c0       	push   $0xc002e1d9
c0024891:	e8 79 2f 00 00       	call   c002780f <debug_panic>

c0024896 <ide_write>:
{
c0024896:	57                   	push   %edi
c0024897:	56                   	push   %esi
c0024898:	53                   	push   %ebx
c0024899:	8b 74 24 10          	mov    0x10(%esp),%esi
  struct channel *c = d->channel;
c002489d:	8b 5e 08             	mov    0x8(%esi),%ebx
  lock_acquire (&c->lock);
c00248a0:	8d 7b 0c             	lea    0xc(%ebx),%edi
c00248a3:	83 ec 0c             	sub    $0xc,%esp
c00248a6:	57                   	push   %edi
c00248a7:	e8 8b dc ff ff       	call   c0022537 <lock_acquire>
  select_sector (d, sec_no);
c00248ac:	8b 54 24 24          	mov    0x24(%esp),%edx
c00248b0:	89 f0                	mov    %esi,%eax
c00248b2:	e8 88 fe ff ff       	call   c002473f <select_sector>
  issue_pio_command (c, CMD_WRITE_SECTOR_RETRY);
c00248b7:	ba 30 00 00 00       	mov    $0x30,%edx
c00248bc:	89 d8                	mov    %ebx,%eax
c00248be:	e8 8c ff ff ff       	call   c002484f <issue_pio_command>
  if (!wait_while_busy (d))
c00248c3:	89 f0                	mov    %esi,%eax
c00248c5:	e8 f5 fe ff ff       	call   c00247bf <wait_while_busy>
c00248ca:	83 c4 10             	add    $0x10,%esp
c00248cd:	84 c0                	test   %al,%al
c00248cf:	74 2a                	je     c00248fb <ide_write+0x65>
   CNT-halfword buffer starting at ADDR. */
static inline void
outsw (uint16_t port, const void *addr, size_t cnt)
{
  /* See [IA32-v2b] "OUTS". */
  asm volatile ("rep outsw" : "+S" (addr), "+c" (cnt) : "d" (port));
c00248d1:	8b 53 08             	mov    0x8(%ebx),%edx
c00248d4:	8b 74 24 18          	mov    0x18(%esp),%esi
c00248d8:	b9 00 01 00 00       	mov    $0x100,%ecx
c00248dd:	66 f3 6f             	rep outsw %ds:(%esi),(%dx)
  sema_down (&c->completion_wait);
c00248e0:	83 ec 0c             	sub    $0xc,%esp
c00248e3:	83 c3 28             	add    $0x28,%ebx
c00248e6:	53                   	push   %ebx
c00248e7:	e8 d5 d9 ff ff       	call   c00222c1 <sema_down>
  lock_release (&c->lock);
c00248ec:	89 3c 24             	mov    %edi,(%esp)
c00248ef:	e8 68 dd ff ff       	call   c002265c <lock_release>
}
c00248f4:	83 c4 10             	add    $0x10,%esp
c00248f7:	5b                   	pop    %ebx
c00248f8:	5e                   	pop    %esi
c00248f9:	5f                   	pop    %edi
c00248fa:	c3                   	ret    
    PANIC ("%s: disk write failed, sector=%"PRDSNu, d->name, sec_no);
c00248fb:	83 ec 08             	sub    $0x8,%esp
c00248fe:	ff 74 24 1c          	pushl  0x1c(%esp)
c0024902:	56                   	push   %esi
c0024903:	68 78 e2 02 c0       	push   $0xc002e278
c0024908:	68 f8 bf 02 c0       	push   $0xc002bff8
c002490d:	68 75 01 00 00       	push   $0x175
c0024912:	68 d9 e1 02 c0       	push   $0xc002e1d9
c0024917:	e8 f3 2e 00 00       	call   c002780f <debug_panic>

c002491c <identify_ata_device>:
{
c002491c:	57                   	push   %edi
c002491d:	56                   	push   %esi
c002491e:	53                   	push   %ebx
c002491f:	81 ec 80 02 00 00    	sub    $0x280,%esp
  struct channel *c = d->channel;
c0024925:	8b 70 08             	mov    0x8(%eax),%esi
  ASSERT (d->is_ata);
c0024928:	80 78 10 00          	cmpb   $0x0,0x10(%eax)
c002492c:	74 49                	je     c0024977 <identify_ata_device+0x5b>
c002492e:	89 c3                	mov    %eax,%ebx
  wait_until_idle (d);
c0024930:	e8 eb fc ff ff       	call   c0024620 <wait_until_idle>
  select_device (d);
c0024935:	89 d8                	mov    %ebx,%eax
c0024937:	e8 44 fd ff ff       	call   c0024680 <select_device>
  wait_until_idle (d);
c002493c:	89 d8                	mov    %ebx,%eax
c002493e:	e8 dd fc ff ff       	call   c0024620 <wait_until_idle>
  issue_pio_command (c, CMD_IDENTIFY_DEVICE);
c0024943:	ba ec 00 00 00       	mov    $0xec,%edx
c0024948:	89 f0                	mov    %esi,%eax
c002494a:	e8 00 ff ff ff       	call   c002484f <issue_pio_command>
  sema_down (&c->completion_wait);
c002494f:	83 ec 0c             	sub    $0xc,%esp
c0024952:	8d 46 28             	lea    0x28(%esi),%eax
c0024955:	50                   	push   %eax
c0024956:	e8 66 d9 ff ff       	call   c00222c1 <sema_down>
  if (!wait_while_busy (d))
c002495b:	89 d8                	mov    %ebx,%eax
c002495d:	e8 5d fe ff ff       	call   c00247bf <wait_while_busy>
c0024962:	83 c4 10             	add    $0x10,%esp
c0024965:	84 c0                	test   %al,%al
c0024967:	75 2f                	jne    c0024998 <identify_ata_device+0x7c>
      d->is_ata = false;
c0024969:	c6 43 10 00          	movb   $0x0,0x10(%ebx)
}
c002496d:	81 c4 80 02 00 00    	add    $0x280,%esp
c0024973:	5b                   	pop    %ebx
c0024974:	5e                   	pop    %esi
c0024975:	5f                   	pop    %edi
c0024976:	c3                   	ret    
  ASSERT (d->is_ata);
c0024977:	83 ec 0c             	sub    $0xc,%esp
c002497a:	68 2c e2 02 c0       	push   $0xc002e22c
c002497f:	68 9f cd 02 c0       	push   $0xc002cd9f
c0024984:	68 04 c0 02 c0       	push   $0xc002c004
c0024989:	68 0d 01 00 00       	push   $0x10d
c002498e:	68 d9 e1 02 c0       	push   $0xc002e1d9
c0024993:	e8 77 2e 00 00       	call   c002780f <debug_panic>
  asm volatile ("rep insw" : "+D" (addr), "+c" (cnt) : "d" (port) : "memory");
c0024998:	8b 56 08             	mov    0x8(%esi),%edx
c002499b:	8d bc 24 80 00 00 00 	lea    0x80(%esp),%edi
c00249a2:	b9 00 01 00 00       	mov    $0x100,%ecx
c00249a7:	66 f3 6d             	rep insw (%dx),%es:(%edi)
  capacity = *(uint32_t *) &id[60 * 2];
c00249aa:	8b b4 24 f8 00 00 00 	mov    0xf8(%esp),%esi
  model = descramble_ata_string (&id[10 * 2], 20);
c00249b1:	ba 14 00 00 00       	mov    $0x14,%edx
c00249b6:	8d 84 24 94 00 00 00 	lea    0x94(%esp),%eax
c00249bd:	e8 9c fb ff ff       	call   c002455e <descramble_ata_string>
c00249c2:	89 c7                	mov    %eax,%edi
  serial = descramble_ata_string (&id[27 * 2], 40);
c00249c4:	ba 28 00 00 00       	mov    $0x28,%edx
c00249c9:	8d 84 24 b6 00 00 00 	lea    0xb6(%esp),%eax
c00249d0:	e8 89 fb ff ff       	call   c002455e <descramble_ata_string>
  snprintf (extra_info, sizeof extra_info,
c00249d5:	83 ec 0c             	sub    $0xc,%esp
c00249d8:	50                   	push   %eax
c00249d9:	57                   	push   %edi
c00249da:	68 36 e2 02 c0       	push   $0xc002e236
c00249df:	68 80 00 00 00       	push   $0x80
c00249e4:	8d 44 24 1c          	lea    0x1c(%esp),%eax
c00249e8:	50                   	push   %eax
c00249e9:	e8 ff 1a 00 00       	call   c00264ed <snprintf>
  if (capacity >= 1024 * 1024 * 1024 / BLOCK_SECTOR_SIZE)
c00249ee:	83 c4 20             	add    $0x20,%esp
c00249f1:	81 fe ff ff 1f 00    	cmp    $0x1fffff,%esi
c00249f7:	76 3a                	jbe    c0024a33 <identify_ata_device+0x117>
      printf ("%s: ignoring ", d->name);
c00249f9:	83 ec 08             	sub    $0x8,%esp
c00249fc:	53                   	push   %ebx
c00249fd:	68 4e e2 02 c0       	push   $0xc002e24e
c0024a02:	e8 5a 13 00 00       	call   c0025d61 <printf>
      print_human_readable_size (capacity * 512);
c0024a07:	83 c4 08             	add    $0x8,%esp
c0024a0a:	89 f0                	mov    %esi,%eax
c0024a0c:	c1 e0 09             	shl    $0x9,%eax
c0024a0f:	ba 00 00 00 00       	mov    $0x0,%edx
c0024a14:	52                   	push   %edx
c0024a15:	50                   	push   %eax
c0024a16:	e8 ea 1c 00 00       	call   c0026705 <print_human_readable_size>
      printf ("disk for safety\n");
c0024a1b:	c7 04 24 5c e2 02 c0 	movl   $0xc002e25c,(%esp)
c0024a22:	e8 36 48 00 00       	call   c002925d <puts>
      d->is_ata = false;
c0024a27:	c6 43 10 00          	movb   $0x0,0x10(%ebx)
      return;
c0024a2b:	83 c4 10             	add    $0x10,%esp
c0024a2e:	e9 3a ff ff ff       	jmp    c002496d <identify_ata_device+0x51>
  block = block_register (d->name, BLOCK_RAW, extra_info, capacity,
c0024a33:	83 ec 08             	sub    $0x8,%esp
c0024a36:	53                   	push   %ebx
c0024a37:	68 e4 68 03 c0       	push   $0xc00368e4
c0024a3c:	56                   	push   %esi
c0024a3d:	8d 44 24 14          	lea    0x14(%esp),%eax
c0024a41:	50                   	push   %eax
c0024a42:	6a 04                	push   $0x4
c0024a44:	53                   	push   %ebx
c0024a45:	e8 d0 f5 ff ff       	call   c002401a <block_register>
  partition_scan (block);
c0024a4a:	83 c4 14             	add    $0x14,%esp
c0024a4d:	50                   	push   %eax
c0024a4e:	e8 bb fa ff ff       	call   c002450e <partition_scan>
c0024a53:	83 c4 10             	add    $0x10,%esp
c0024a56:	e9 12 ff ff ff       	jmp    c002496d <identify_ata_device+0x51>

c0024a5b <ide_read>:
{
c0024a5b:	55                   	push   %ebp
c0024a5c:	57                   	push   %edi
c0024a5d:	56                   	push   %esi
c0024a5e:	53                   	push   %ebx
c0024a5f:	83 ec 18             	sub    $0x18,%esp
c0024a62:	8b 74 24 2c          	mov    0x2c(%esp),%esi
  struct channel *c = d->channel;
c0024a66:	8b 5e 08             	mov    0x8(%esi),%ebx
  lock_acquire (&c->lock);
c0024a69:	8d 6b 0c             	lea    0xc(%ebx),%ebp
c0024a6c:	55                   	push   %ebp
c0024a6d:	e8 c5 da ff ff       	call   c0022537 <lock_acquire>
  select_sector (d, sec_no);
c0024a72:	8b 54 24 34          	mov    0x34(%esp),%edx
c0024a76:	89 f0                	mov    %esi,%eax
c0024a78:	e8 c2 fc ff ff       	call   c002473f <select_sector>
  issue_pio_command (c, CMD_READ_SECTOR_RETRY);
c0024a7d:	ba 20 00 00 00       	mov    $0x20,%edx
c0024a82:	89 d8                	mov    %ebx,%eax
c0024a84:	e8 c6 fd ff ff       	call   c002484f <issue_pio_command>
  sema_down (&c->completion_wait);
c0024a89:	8d 43 28             	lea    0x28(%ebx),%eax
c0024a8c:	89 04 24             	mov    %eax,(%esp)
c0024a8f:	e8 2d d8 ff ff       	call   c00222c1 <sema_down>
  if (!wait_while_busy (d))
c0024a94:	89 f0                	mov    %esi,%eax
c0024a96:	e8 24 fd ff ff       	call   c00247bf <wait_while_busy>
c0024a9b:	83 c4 10             	add    $0x10,%esp
c0024a9e:	84 c0                	test   %al,%al
c0024aa0:	74 20                	je     c0024ac2 <ide_read+0x67>
c0024aa2:	8b 53 08             	mov    0x8(%ebx),%edx
c0024aa5:	8b 7c 24 28          	mov    0x28(%esp),%edi
c0024aa9:	b9 00 01 00 00       	mov    $0x100,%ecx
c0024aae:	66 f3 6d             	rep insw (%dx),%es:(%edi)
  lock_release (&c->lock);
c0024ab1:	83 ec 0c             	sub    $0xc,%esp
c0024ab4:	55                   	push   %ebp
c0024ab5:	e8 a2 db ff ff       	call   c002265c <lock_release>
}
c0024aba:	83 c4 1c             	add    $0x1c,%esp
c0024abd:	5b                   	pop    %ebx
c0024abe:	5e                   	pop    %esi
c0024abf:	5f                   	pop    %edi
c0024ac0:	5d                   	pop    %ebp
c0024ac1:	c3                   	ret    
    PANIC ("%s: disk read failed, sector=%"PRDSNu, d->name, sec_no);
c0024ac2:	83 ec 08             	sub    $0x8,%esp
c0024ac5:	ff 74 24 2c          	pushl  0x2c(%esp)
c0024ac9:	56                   	push   %esi
c0024aca:	68 9c e2 02 c0       	push   $0xc002e29c
c0024acf:	68 dc bf 02 c0       	push   $0xc002bfdc
c0024ad4:	68 62 01 00 00       	push   $0x162
c0024ad9:	68 d9 e1 02 c0       	push   $0xc002e1d9
c0024ade:	e8 2c 2d 00 00       	call   c002780f <debug_panic>

c0024ae3 <ide_init>:
{
c0024ae3:	55                   	push   %ebp
c0024ae4:	57                   	push   %edi
c0024ae5:	56                   	push   %esi
c0024ae6:	53                   	push   %ebx
c0024ae7:	83 ec 1c             	sub    $0x1c,%esp
      snprintf (c->name, sizeof c->name, "ide%zu", chan_no);
c0024aea:	6a 00                	push   $0x0
c0024aec:	68 6c e2 02 c0       	push   $0xc002e26c
c0024af1:	6a 08                	push   $0x8
c0024af3:	68 c0 81 03 c0       	push   $0xc00381c0
c0024af8:	e8 f0 19 00 00       	call   c00264ed <snprintf>
          c->reg_base = 0x1f0;
c0024afd:	66 c7 05 c8 81 03 c0 	movw   $0x1f0,0xc00381c8
c0024b04:	f0 01 
          c->irq = 14 + 0x20;
c0024b06:	c6 05 ca 81 03 c0 2e 	movb   $0x2e,0xc00381ca
      lock_init (&c->lock);
c0024b0d:	c7 04 24 cc 81 03 c0 	movl   $0xc00381cc,(%esp)
c0024b14:	e8 9c d9 ff ff       	call   c00224b5 <lock_init>
      c->expecting_interrupt = false;
c0024b19:	c6 05 e4 81 03 c0 00 	movb   $0x0,0xc00381e4
      sema_init (&c->completion_wait, 0);
c0024b20:	83 c4 08             	add    $0x8,%esp
c0024b23:	6a 00                	push   $0x0
c0024b25:	68 e8 81 03 c0       	push   $0xc00381e8
c0024b2a:	e8 53 d7 ff ff       	call   c0022282 <sema_init>
          snprintf (d->name, sizeof d->name,
c0024b2f:	6a 61                	push   $0x61
c0024b31:	68 73 e2 02 c0       	push   $0xc002e273
c0024b36:	6a 08                	push   $0x8
c0024b38:	68 fc 81 03 c0       	push   $0xc00381fc
c0024b3d:	e8 ab 19 00 00       	call   c00264ed <snprintf>
          d->channel = c;
c0024b42:	c7 05 04 82 03 c0 c0 	movl   $0xc00381c0,0xc0038204
c0024b49:	81 03 c0 
          d->dev_no = dev_no;
c0024b4c:	c7 05 08 82 03 c0 00 	movl   $0x0,0xc0038208
c0024b53:	00 00 00 
          d->is_ata = false;
c0024b56:	c6 05 0c 82 03 c0 00 	movb   $0x0,0xc003820c
          snprintf (d->name, sizeof d->name,
c0024b5d:	83 c4 20             	add    $0x20,%esp
c0024b60:	6a 62                	push   $0x62
c0024b62:	68 73 e2 02 c0       	push   $0xc002e273
c0024b67:	6a 08                	push   $0x8
c0024b69:	68 10 82 03 c0       	push   $0xc0038210
c0024b6e:	e8 7a 19 00 00       	call   c00264ed <snprintf>
          d->channel = c;
c0024b73:	c7 05 18 82 03 c0 c0 	movl   $0xc00381c0,0xc0038218
c0024b7a:	81 03 c0 
          d->dev_no = dev_no;
c0024b7d:	c7 05 1c 82 03 c0 01 	movl   $0x1,0xc003821c
c0024b84:	00 00 00 
          d->is_ata = false;
c0024b87:	c6 05 20 82 03 c0 00 	movb   $0x0,0xc0038220
      intr_register_ext (c->irq, interrupt_handler, c->name);
c0024b8e:	83 c4 0c             	add    $0xc,%esp
c0024b91:	68 c0 81 03 c0       	push   $0xc00381c0
c0024b96:	68 aa 45 02 c0       	push   $0xc00245aa
c0024b9b:	0f b6 05 ca 81 03 c0 	movzbl 0xc00381ca,%eax
c0024ba2:	50                   	push   %eax
c0024ba3:	e8 2d c8 ff ff       	call   c00213d5 <intr_register_ext>
      select_device (d);
c0024ba8:	b8 fc 81 03 c0       	mov    $0xc00381fc,%eax
c0024bad:	e8 ce fa ff ff       	call   c0024680 <select_device>
      outb (reg_nsect (c), 0x55);
c0024bb2:	8b 0d c8 81 03 c0    	mov    0xc00381c8,%ecx
c0024bb8:	8d 59 02             	lea    0x2(%ecx),%ebx
  asm volatile ("outb %b0, %w1" : : "a" (data), "Nd" (port));
c0024bbb:	b0 55                	mov    $0x55,%al
c0024bbd:	89 da                	mov    %ebx,%edx
c0024bbf:	ee                   	out    %al,(%dx)
      outb (reg_lbal (c), 0xaa);
c0024bc0:	83 c1 03             	add    $0x3,%ecx
c0024bc3:	b0 aa                	mov    $0xaa,%al
c0024bc5:	89 ca                	mov    %ecx,%edx
c0024bc7:	ee                   	out    %al,(%dx)
c0024bc8:	89 da                	mov    %ebx,%edx
c0024bca:	ee                   	out    %al,(%dx)
c0024bcb:	b0 55                	mov    $0x55,%al
c0024bcd:	89 ca                	mov    %ecx,%edx
c0024bcf:	ee                   	out    %al,(%dx)
c0024bd0:	89 da                	mov    %ebx,%edx
c0024bd2:	ee                   	out    %al,(%dx)
c0024bd3:	b0 aa                	mov    $0xaa,%al
c0024bd5:	89 ca                	mov    %ecx,%edx
c0024bd7:	ee                   	out    %al,(%dx)
  asm volatile ("inb %w1, %b0" : "=a" (data) : "Nd" (port));
c0024bd8:	89 da                	mov    %ebx,%edx
c0024bda:	ec                   	in     (%dx),%al
                         && inb (reg_lbal (c)) == 0xaa);
c0024bdb:	83 c4 10             	add    $0x10,%esp
c0024bde:	3c 55                	cmp    $0x55,%al
c0024be0:	0f 84 84 02 00 00    	je     c0024e6a <ide_init+0x387>
c0024be6:	b3 00                	mov    $0x0,%bl
      present[dev_no] = (inb (reg_nsect (c)) == 0x55
c0024be8:	88 5c 24 0e          	mov    %bl,0xe(%esp)
      select_device (d);
c0024bec:	b8 10 82 03 c0       	mov    $0xc0038210,%eax
c0024bf1:	e8 8a fa ff ff       	call   c0024680 <select_device>
      outb (reg_nsect (c), 0x55);
c0024bf6:	8b 0d c8 81 03 c0    	mov    0xc00381c8,%ecx
c0024bfc:	8d 71 02             	lea    0x2(%ecx),%esi
  asm volatile ("outb %b0, %w1" : : "a" (data), "Nd" (port));
c0024bff:	b0 55                	mov    $0x55,%al
c0024c01:	89 f2                	mov    %esi,%edx
c0024c03:	ee                   	out    %al,(%dx)
      outb (reg_lbal (c), 0xaa);
c0024c04:	8d 79 03             	lea    0x3(%ecx),%edi
c0024c07:	b0 aa                	mov    $0xaa,%al
c0024c09:	89 fa                	mov    %edi,%edx
c0024c0b:	ee                   	out    %al,(%dx)
c0024c0c:	89 f2                	mov    %esi,%edx
c0024c0e:	ee                   	out    %al,(%dx)
c0024c0f:	b0 55                	mov    $0x55,%al
c0024c11:	89 fa                	mov    %edi,%edx
c0024c13:	ee                   	out    %al,(%dx)
c0024c14:	89 f2                	mov    %esi,%edx
c0024c16:	ee                   	out    %al,(%dx)
c0024c17:	b0 aa                	mov    $0xaa,%al
c0024c19:	89 fa                	mov    %edi,%edx
c0024c1b:	ee                   	out    %al,(%dx)
  asm volatile ("inb %w1, %b0" : "=a" (data) : "Nd" (port));
c0024c1c:	89 f2                	mov    %esi,%edx
c0024c1e:	ec                   	in     (%dx),%al
                         && inb (reg_lbal (c)) == 0xaa);
c0024c1f:	3c 55                	cmp    $0x55,%al
c0024c21:	0f 84 50 02 00 00    	je     c0024e77 <ide_init+0x394>
c0024c27:	be 00 00 00 00       	mov    $0x0,%esi
      present[dev_no] = (inb (reg_nsect (c)) == 0x55
c0024c2c:	89 f0                	mov    %esi,%eax
c0024c2e:	88 44 24 0f          	mov    %al,0xf(%esp)
  outb (reg_ctl (c), 0);
c0024c32:	8d 91 06 02 00 00    	lea    0x206(%ecx),%edx
  asm volatile ("outb %b0, %w1" : : "a" (data), "Nd" (port));
c0024c38:	b0 00                	mov    $0x0,%al
c0024c3a:	ee                   	out    %al,(%dx)
  timer_usleep (10);
c0024c3b:	83 ec 08             	sub    $0x8,%esp
c0024c3e:	6a 00                	push   $0x0
c0024c40:	6a 0a                	push   $0xa
c0024c42:	e8 56 e9 ff ff       	call   c002359d <timer_usleep>
  outb (reg_ctl (c), CTL_SRST);
c0024c47:	a1 c8 81 03 c0       	mov    0xc00381c8,%eax
c0024c4c:	8d 90 06 02 00 00    	lea    0x206(%eax),%edx
c0024c52:	b0 04                	mov    $0x4,%al
c0024c54:	ee                   	out    %al,(%dx)
  timer_usleep (10);
c0024c55:	83 c4 08             	add    $0x8,%esp
c0024c58:	6a 00                	push   $0x0
c0024c5a:	6a 0a                	push   $0xa
c0024c5c:	e8 3c e9 ff ff       	call   c002359d <timer_usleep>
  outb (reg_ctl (c), 0);
c0024c61:	a1 c8 81 03 c0       	mov    0xc00381c8,%eax
c0024c66:	8d 90 06 02 00 00    	lea    0x206(%eax),%edx
c0024c6c:	b0 00                	mov    $0x0,%al
c0024c6e:	ee                   	out    %al,(%dx)
  timer_msleep (150);
c0024c6f:	83 c4 08             	add    $0x8,%esp
c0024c72:	6a 00                	push   $0x0
c0024c74:	68 96 00 00 00       	push   $0x96
c0024c79:	e8 06 e9 ff ff       	call   c0023584 <timer_msleep>
  if (present[0]) 
c0024c7e:	83 c4 10             	add    $0x10,%esp
c0024c81:	84 db                	test   %bl,%bl
c0024c83:	0f 85 fd 01 00 00    	jne    c0024e86 <ide_init+0x3a3>
  if (present[1])
c0024c89:	89 f0                	mov    %esi,%eax
c0024c8b:	84 c0                	test   %al,%al
c0024c8d:	0f 85 0c 02 00 00    	jne    c0024e9f <ide_init+0x3bc>
      if (check_device_type (&c->devices[0]))
c0024c93:	b8 fc 81 03 c0       	mov    $0xc00381fc,%eax
c0024c98:	e8 16 fa ff ff       	call   c00246b3 <check_device_type>
c0024c9d:	84 c0                	test   %al,%al
c0024c9f:	0f 85 42 02 00 00    	jne    c0024ee7 <ide_init+0x404>
        if (c->devices[dev_no].is_ata)
c0024ca5:	80 3d 0c 82 03 c0 00 	cmpb   $0x0,0xc003820c
c0024cac:	0f 85 44 02 00 00    	jne    c0024ef6 <ide_init+0x413>
c0024cb2:	80 3d 20 82 03 c0 00 	cmpb   $0x0,0xc0038220
c0024cb9:	0f 85 46 02 00 00    	jne    c0024f05 <ide_init+0x422>
      snprintf (c->name, sizeof c->name, "ide%zu", chan_no);
c0024cbf:	6a 01                	push   $0x1
c0024cc1:	68 6c e2 02 c0       	push   $0xc002e26c
c0024cc6:	6a 08                	push   $0x8
c0024cc8:	68 24 82 03 c0       	push   $0xc0038224
c0024ccd:	e8 1b 18 00 00       	call   c00264ed <snprintf>
          c->reg_base = 0x170;
c0024cd2:	66 c7 05 2c 82 03 c0 	movw   $0x170,0xc003822c
c0024cd9:	70 01 
          c->irq = 15 + 0x20;
c0024cdb:	c6 05 2e 82 03 c0 2f 	movb   $0x2f,0xc003822e
      lock_init (&c->lock);
c0024ce2:	c7 04 24 30 82 03 c0 	movl   $0xc0038230,(%esp)
c0024ce9:	e8 c7 d7 ff ff       	call   c00224b5 <lock_init>
      c->expecting_interrupt = false;
c0024cee:	c6 05 48 82 03 c0 00 	movb   $0x0,0xc0038248
      sema_init (&c->completion_wait, 0);
c0024cf5:	83 c4 08             	add    $0x8,%esp
c0024cf8:	6a 00                	push   $0x0
c0024cfa:	68 4c 82 03 c0       	push   $0xc003824c
c0024cff:	e8 7e d5 ff ff       	call   c0022282 <sema_init>
          snprintf (d->name, sizeof d->name,
c0024d04:	6a 63                	push   $0x63
c0024d06:	68 73 e2 02 c0       	push   $0xc002e273
c0024d0b:	6a 08                	push   $0x8
c0024d0d:	68 60 82 03 c0       	push   $0xc0038260
c0024d12:	e8 d6 17 00 00       	call   c00264ed <snprintf>
          d->channel = c;
c0024d17:	c7 05 68 82 03 c0 24 	movl   $0xc0038224,0xc0038268
c0024d1e:	82 03 c0 
          d->dev_no = dev_no;
c0024d21:	c7 05 6c 82 03 c0 00 	movl   $0x0,0xc003826c
c0024d28:	00 00 00 
          d->is_ata = false;
c0024d2b:	c6 05 70 82 03 c0 00 	movb   $0x0,0xc0038270
          snprintf (d->name, sizeof d->name,
c0024d32:	83 c4 20             	add    $0x20,%esp
c0024d35:	6a 64                	push   $0x64
c0024d37:	68 73 e2 02 c0       	push   $0xc002e273
c0024d3c:	6a 08                	push   $0x8
c0024d3e:	68 74 82 03 c0       	push   $0xc0038274
c0024d43:	e8 a5 17 00 00       	call   c00264ed <snprintf>
          d->channel = c;
c0024d48:	c7 05 7c 82 03 c0 24 	movl   $0xc0038224,0xc003827c
c0024d4f:	82 03 c0 
          d->dev_no = dev_no;
c0024d52:	c7 05 80 82 03 c0 01 	movl   $0x1,0xc0038280
c0024d59:	00 00 00 
          d->is_ata = false;
c0024d5c:	c6 05 84 82 03 c0 00 	movb   $0x0,0xc0038284
      intr_register_ext (c->irq, interrupt_handler, c->name);
c0024d63:	83 c4 0c             	add    $0xc,%esp
c0024d66:	68 24 82 03 c0       	push   $0xc0038224
c0024d6b:	68 aa 45 02 c0       	push   $0xc00245aa
c0024d70:	0f b6 05 2e 82 03 c0 	movzbl 0xc003822e,%eax
c0024d77:	50                   	push   %eax
c0024d78:	e8 58 c6 ff ff       	call   c00213d5 <intr_register_ext>
c0024d7d:	bf 60 82 03 c0       	mov    $0xc0038260,%edi
c0024d82:	8d 74 24 1e          	lea    0x1e(%esp),%esi
c0024d86:	83 c4 10             	add    $0x10,%esp
      select_device (d);
c0024d89:	89 f8                	mov    %edi,%eax
c0024d8b:	e8 f0 f8 ff ff       	call   c0024680 <select_device>
      outb (reg_nsect (c), 0x55);
c0024d90:	8b 2d 2c 82 03 c0    	mov    0xc003822c,%ebp
c0024d96:	8d 4d 02             	lea    0x2(%ebp),%ecx
c0024d99:	b0 55                	mov    $0x55,%al
c0024d9b:	89 ca                	mov    %ecx,%edx
c0024d9d:	ee                   	out    %al,(%dx)
      outb (reg_lbal (c), 0xaa);
c0024d9e:	8d 5d 03             	lea    0x3(%ebp),%ebx
c0024da1:	b0 aa                	mov    $0xaa,%al
c0024da3:	89 da                	mov    %ebx,%edx
c0024da5:	ee                   	out    %al,(%dx)
c0024da6:	89 ca                	mov    %ecx,%edx
c0024da8:	ee                   	out    %al,(%dx)
c0024da9:	b0 55                	mov    $0x55,%al
c0024dab:	89 da                	mov    %ebx,%edx
c0024dad:	ee                   	out    %al,(%dx)
c0024dae:	89 ca                	mov    %ecx,%edx
c0024db0:	ee                   	out    %al,(%dx)
c0024db1:	b0 aa                	mov    $0xaa,%al
c0024db3:	89 da                	mov    %ebx,%edx
c0024db5:	ee                   	out    %al,(%dx)
  asm volatile ("inb %w1, %b0" : "=a" (data) : "Nd" (port));
c0024db6:	89 ca                	mov    %ecx,%edx
c0024db8:	ec                   	in     (%dx),%al
                         && inb (reg_lbal (c)) == 0xaa);
c0024db9:	3c 55                	cmp    $0x55,%al
c0024dbb:	0f 84 53 01 00 00    	je     c0024f14 <ide_init+0x431>
c0024dc1:	b0 00                	mov    $0x0,%al
      present[dev_no] = (inb (reg_nsect (c)) == 0x55
c0024dc3:	88 06                	mov    %al,(%esi)
c0024dc5:	83 c7 14             	add    $0x14,%edi
c0024dc8:	46                   	inc    %esi
  for (dev_no = 0; dev_no < 2; dev_no++)
c0024dc9:	8d 44 24 10          	lea    0x10(%esp),%eax
c0024dcd:	39 f0                	cmp    %esi,%eax
c0024dcf:	75 b8                	jne    c0024d89 <ide_init+0x2a6>
  outb (reg_ctl (c), 0);
c0024dd1:	8d 95 06 02 00 00    	lea    0x206(%ebp),%edx
  asm volatile ("outb %b0, %w1" : : "a" (data), "Nd" (port));
c0024dd7:	b0 00                	mov    $0x0,%al
c0024dd9:	ee                   	out    %al,(%dx)
  timer_usleep (10);
c0024dda:	83 ec 08             	sub    $0x8,%esp
c0024ddd:	6a 00                	push   $0x0
c0024ddf:	6a 0a                	push   $0xa
c0024de1:	e8 b7 e7 ff ff       	call   c002359d <timer_usleep>
  outb (reg_ctl (c), CTL_SRST);
c0024de6:	a1 2c 82 03 c0       	mov    0xc003822c,%eax
c0024deb:	8d 90 06 02 00 00    	lea    0x206(%eax),%edx
c0024df1:	b0 04                	mov    $0x4,%al
c0024df3:	ee                   	out    %al,(%dx)
  timer_usleep (10);
c0024df4:	83 c4 08             	add    $0x8,%esp
c0024df7:	6a 00                	push   $0x0
c0024df9:	6a 0a                	push   $0xa
c0024dfb:	e8 9d e7 ff ff       	call   c002359d <timer_usleep>
  outb (reg_ctl (c), 0);
c0024e00:	a1 2c 82 03 c0       	mov    0xc003822c,%eax
c0024e05:	8d 90 06 02 00 00    	lea    0x206(%eax),%edx
c0024e0b:	b0 00                	mov    $0x0,%al
c0024e0d:	ee                   	out    %al,(%dx)
  timer_msleep (150);
c0024e0e:	83 c4 08             	add    $0x8,%esp
c0024e11:	6a 00                	push   $0x0
c0024e13:	68 96 00 00 00       	push   $0x96
c0024e18:	e8 67 e7 ff ff       	call   c0023584 <timer_msleep>
  if (present[0]) 
c0024e1d:	83 c4 10             	add    $0x10,%esp
c0024e20:	80 7c 24 0e 00       	cmpb   $0x0,0xe(%esp)
c0024e25:	0f 85 f6 00 00 00    	jne    c0024f21 <ide_init+0x43e>
  if (present[1])
c0024e2b:	80 7c 24 0f 00       	cmpb   $0x0,0xf(%esp)
c0024e30:	0f 85 04 01 00 00    	jne    c0024f3a <ide_init+0x457>
      if (check_device_type (&c->devices[0]))
c0024e36:	b8 60 82 03 c0       	mov    $0xc0038260,%eax
c0024e3b:	e8 73 f8 ff ff       	call   c00246b3 <check_device_type>
c0024e40:	84 c0                	test   %al,%al
c0024e42:	0f 85 3a 01 00 00    	jne    c0024f82 <ide_init+0x49f>
        if (c->devices[dev_no].is_ata)
c0024e48:	80 3d 70 82 03 c0 00 	cmpb   $0x0,0xc0038270
c0024e4f:	0f 85 3c 01 00 00    	jne    c0024f91 <ide_init+0x4ae>
c0024e55:	80 3d 84 82 03 c0 00 	cmpb   $0x0,0xc0038284
c0024e5c:	0f 85 3e 01 00 00    	jne    c0024fa0 <ide_init+0x4bd>
}
c0024e62:	83 c4 1c             	add    $0x1c,%esp
c0024e65:	5b                   	pop    %ebx
c0024e66:	5e                   	pop    %esi
c0024e67:	5f                   	pop    %edi
c0024e68:	5d                   	pop    %ebp
c0024e69:	c3                   	ret    
  asm volatile ("inb %w1, %b0" : "=a" (data) : "Nd" (port));
c0024e6a:	89 ca                	mov    %ecx,%edx
c0024e6c:	ec                   	in     (%dx),%al
                         && inb (reg_lbal (c)) == 0xaa);
c0024e6d:	3c aa                	cmp    $0xaa,%al
c0024e6f:	0f 94 c3             	sete   %bl
c0024e72:	e9 71 fd ff ff       	jmp    c0024be8 <ide_init+0x105>
c0024e77:	89 fa                	mov    %edi,%edx
c0024e79:	ec                   	in     (%dx),%al
c0024e7a:	3c aa                	cmp    $0xaa,%al
c0024e7c:	0f 94 c0             	sete   %al
c0024e7f:	89 c6                	mov    %eax,%esi
c0024e81:	e9 a6 fd ff ff       	jmp    c0024c2c <ide_init+0x149>
      select_device (&c->devices[0]);
c0024e86:	b8 fc 81 03 c0       	mov    $0xc00381fc,%eax
c0024e8b:	e8 f0 f7 ff ff       	call   c0024680 <select_device>
      wait_while_busy (&c->devices[0]); 
c0024e90:	b8 fc 81 03 c0       	mov    $0xc00381fc,%eax
c0024e95:	e8 25 f9 ff ff       	call   c00247bf <wait_while_busy>
c0024e9a:	e9 ea fd ff ff       	jmp    c0024c89 <ide_init+0x1a6>
      select_device (&c->devices[1]);
c0024e9f:	b8 10 82 03 c0       	mov    $0xc0038210,%eax
c0024ea4:	e8 d7 f7 ff ff       	call   c0024680 <select_device>
c0024ea9:	bb b8 0b 00 00       	mov    $0xbb8,%ebx
c0024eae:	eb 12                	jmp    c0024ec2 <ide_init+0x3df>
          timer_msleep (10);
c0024eb0:	83 ec 08             	sub    $0x8,%esp
c0024eb3:	6a 00                	push   $0x0
c0024eb5:	6a 0a                	push   $0xa
c0024eb7:	e8 c8 e6 ff ff       	call   c0023584 <timer_msleep>
      for (i = 0; i < 3000; i++) 
c0024ebc:	83 c4 10             	add    $0x10,%esp
c0024ebf:	4b                   	dec    %ebx
c0024ec0:	74 16                	je     c0024ed8 <ide_init+0x3f5>
          if (inb (reg_nsect (c)) == 1 && inb (reg_lbal (c)) == 1)
c0024ec2:	8b 0d c8 81 03 c0    	mov    0xc00381c8,%ecx
c0024ec8:	8d 51 02             	lea    0x2(%ecx),%edx
c0024ecb:	ec                   	in     (%dx),%al
c0024ecc:	3c 01                	cmp    $0x1,%al
c0024ece:	75 e0                	jne    c0024eb0 <ide_init+0x3cd>
c0024ed0:	8d 51 03             	lea    0x3(%ecx),%edx
c0024ed3:	ec                   	in     (%dx),%al
c0024ed4:	3c 01                	cmp    $0x1,%al
c0024ed6:	75 d8                	jne    c0024eb0 <ide_init+0x3cd>
      wait_while_busy (&c->devices[1]);
c0024ed8:	b8 10 82 03 c0       	mov    $0xc0038210,%eax
c0024edd:	e8 dd f8 ff ff       	call   c00247bf <wait_while_busy>
c0024ee2:	e9 ac fd ff ff       	jmp    c0024c93 <ide_init+0x1b0>
        check_device_type (&c->devices[1]);
c0024ee7:	b8 10 82 03 c0       	mov    $0xc0038210,%eax
c0024eec:	e8 c2 f7 ff ff       	call   c00246b3 <check_device_type>
c0024ef1:	e9 af fd ff ff       	jmp    c0024ca5 <ide_init+0x1c2>
          identify_ata_device (&c->devices[dev_no]);
c0024ef6:	b8 fc 81 03 c0       	mov    $0xc00381fc,%eax
c0024efb:	e8 1c fa ff ff       	call   c002491c <identify_ata_device>
c0024f00:	e9 ad fd ff ff       	jmp    c0024cb2 <ide_init+0x1cf>
c0024f05:	b8 10 82 03 c0       	mov    $0xc0038210,%eax
c0024f0a:	e8 0d fa ff ff       	call   c002491c <identify_ata_device>
c0024f0f:	e9 ab fd ff ff       	jmp    c0024cbf <ide_init+0x1dc>
c0024f14:	89 da                	mov    %ebx,%edx
c0024f16:	ec                   	in     (%dx),%al
                         && inb (reg_lbal (c)) == 0xaa);
c0024f17:	3c aa                	cmp    $0xaa,%al
c0024f19:	0f 94 c0             	sete   %al
c0024f1c:	e9 a2 fe ff ff       	jmp    c0024dc3 <ide_init+0x2e0>
      select_device (&c->devices[0]);
c0024f21:	b8 60 82 03 c0       	mov    $0xc0038260,%eax
c0024f26:	e8 55 f7 ff ff       	call   c0024680 <select_device>
      wait_while_busy (&c->devices[0]); 
c0024f2b:	b8 60 82 03 c0       	mov    $0xc0038260,%eax
c0024f30:	e8 8a f8 ff ff       	call   c00247bf <wait_while_busy>
c0024f35:	e9 f1 fe ff ff       	jmp    c0024e2b <ide_init+0x348>
      select_device (&c->devices[1]);
c0024f3a:	b8 74 82 03 c0       	mov    $0xc0038274,%eax
c0024f3f:	e8 3c f7 ff ff       	call   c0024680 <select_device>
c0024f44:	bb b8 0b 00 00       	mov    $0xbb8,%ebx
c0024f49:	eb 12                	jmp    c0024f5d <ide_init+0x47a>
          timer_msleep (10);
c0024f4b:	83 ec 08             	sub    $0x8,%esp
c0024f4e:	6a 00                	push   $0x0
c0024f50:	6a 0a                	push   $0xa
c0024f52:	e8 2d e6 ff ff       	call   c0023584 <timer_msleep>
      for (i = 0; i < 3000; i++) 
c0024f57:	83 c4 10             	add    $0x10,%esp
c0024f5a:	4b                   	dec    %ebx
c0024f5b:	74 16                	je     c0024f73 <ide_init+0x490>
          if (inb (reg_nsect (c)) == 1 && inb (reg_lbal (c)) == 1)
c0024f5d:	8b 0d 2c 82 03 c0    	mov    0xc003822c,%ecx
c0024f63:	8d 51 02             	lea    0x2(%ecx),%edx
c0024f66:	ec                   	in     (%dx),%al
c0024f67:	3c 01                	cmp    $0x1,%al
c0024f69:	75 e0                	jne    c0024f4b <ide_init+0x468>
c0024f6b:	8d 51 03             	lea    0x3(%ecx),%edx
c0024f6e:	ec                   	in     (%dx),%al
c0024f6f:	3c 01                	cmp    $0x1,%al
c0024f71:	75 d8                	jne    c0024f4b <ide_init+0x468>
      wait_while_busy (&c->devices[1]);
c0024f73:	b8 74 82 03 c0       	mov    $0xc0038274,%eax
c0024f78:	e8 42 f8 ff ff       	call   c00247bf <wait_while_busy>
c0024f7d:	e9 b4 fe ff ff       	jmp    c0024e36 <ide_init+0x353>
        check_device_type (&c->devices[1]);
c0024f82:	b8 74 82 03 c0       	mov    $0xc0038274,%eax
c0024f87:	e8 27 f7 ff ff       	call   c00246b3 <check_device_type>
c0024f8c:	e9 b7 fe ff ff       	jmp    c0024e48 <ide_init+0x365>
          identify_ata_device (&c->devices[dev_no]);
c0024f91:	b8 60 82 03 c0       	mov    $0xc0038260,%eax
c0024f96:	e8 81 f9 ff ff       	call   c002491c <identify_ata_device>
c0024f9b:	e9 b5 fe ff ff       	jmp    c0024e55 <ide_init+0x372>
c0024fa0:	b8 74 82 03 c0       	mov    $0xc0038274,%eax
c0024fa5:	e8 72 f9 ff ff       	call   c002491c <identify_ata_device>
}
c0024faa:	e9 b3 fe ff ff       	jmp    c0024e62 <ide_init+0x37f>

c0024faf <input_init>:
static struct intq buffer;

/* Initializes the input buffer. */
void
input_init (void) 
{
c0024faf:	83 ec 18             	sub    $0x18,%esp
  intq_init (&buffer);
c0024fb2:	68 a0 82 03 c0       	push   $0xc00382a0
c0024fb7:	e8 eb 00 00 00       	call   c00250a7 <intq_init>
}
c0024fbc:	83 c4 1c             	add    $0x1c,%esp
c0024fbf:	c3                   	ret    

c0024fc0 <input_putc>:

/* Adds a key to the input buffer.
   Interrupts must be off and the buffer must not be full. */
void
input_putc (uint8_t key) 
{
c0024fc0:	53                   	push   %ebx
c0024fc1:	83 ec 08             	sub    $0x8,%esp
c0024fc4:	8b 5c 24 10          	mov    0x10(%esp),%ebx
  ASSERT (intr_get_level () == INTR_OFF);
c0024fc8:	e8 4a c2 ff ff       	call   c0021217 <intr_get_level>
c0024fcd:	85 c0                	test   %eax,%eax
c0024fcf:	75 2f                	jne    c0025000 <input_putc+0x40>
  ASSERT (!intq_full (&buffer));
c0024fd1:	83 ec 0c             	sub    $0xc,%esp
c0024fd4:	68 a0 82 03 c0       	push   $0xc00382a0
c0024fd9:	e8 35 01 00 00       	call   c0025113 <intq_full>
c0024fde:	83 c4 10             	add    $0x10,%esp
c0024fe1:	84 c0                	test   %al,%al
c0024fe3:	75 39                	jne    c002501e <input_putc+0x5e>

  intq_putc (&buffer, key);
c0024fe5:	83 ec 08             	sub    $0x8,%esp
c0024fe8:	0f b6 db             	movzbl %bl,%ebx
c0024feb:	53                   	push   %ebx
c0024fec:	68 a0 82 03 c0       	push   $0xc00382a0
c0024ff1:	e8 71 03 00 00       	call   c0025367 <intq_putc>
  serial_notify ();
c0024ff6:	e8 5e ed ff ff       	call   c0023d59 <serial_notify>
}
c0024ffb:	83 c4 18             	add    $0x18,%esp
c0024ffe:	5b                   	pop    %ebx
c0024fff:	c3                   	ret    
  ASSERT (intr_get_level () == INTR_OFF);
c0025000:	83 ec 0c             	sub    $0xc,%esp
c0025003:	68 20 d1 02 c0       	push   $0xc002d120
c0025008:	68 9f cd 02 c0       	push   $0xc002cd9f
c002500d:	68 38 c0 02 c0       	push   $0xc002c038
c0025012:	6a 15                	push   $0x15
c0025014:	68 bc e2 02 c0       	push   $0xc002e2bc
c0025019:	e8 f1 27 00 00       	call   c002780f <debug_panic>
  ASSERT (!intq_full (&buffer));
c002501e:	83 ec 0c             	sub    $0xc,%esp
c0025021:	68 d2 e2 02 c0       	push   $0xc002e2d2
c0025026:	68 9f cd 02 c0       	push   $0xc002cd9f
c002502b:	68 38 c0 02 c0       	push   $0xc002c038
c0025030:	6a 16                	push   $0x16
c0025032:	68 bc e2 02 c0       	push   $0xc002e2bc
c0025037:	e8 d3 27 00 00       	call   c002780f <debug_panic>

c002503c <input_getc>:

/* Retrieves a key from the input buffer.
   If the buffer is empty, waits for a key to be pressed. */
uint8_t
input_getc (void) 
{
c002503c:	56                   	push   %esi
c002503d:	53                   	push   %ebx
c002503e:	83 ec 04             	sub    $0x4,%esp
  enum intr_level old_level;
  uint8_t key;

  old_level = intr_disable ();
c0025041:	e8 0e c2 ff ff       	call   c0021254 <intr_disable>
c0025046:	89 c6                	mov    %eax,%esi
  key = intq_getc (&buffer);
c0025048:	83 ec 0c             	sub    $0xc,%esp
c002504b:	68 a0 82 03 c0       	push   $0xc00382a0
c0025050:	e8 5d 02 00 00       	call   c00252b2 <intq_getc>
c0025055:	88 c3                	mov    %al,%bl
  serial_notify ();
c0025057:	e8 fd ec ff ff       	call   c0023d59 <serial_notify>
  intr_set_level (old_level);
c002505c:	89 34 24             	mov    %esi,(%esp)
c002505f:	e8 f7 c1 ff ff       	call   c002125b <intr_set_level>
  
  return key;
}
c0025064:	88 d8                	mov    %bl,%al
c0025066:	83 c4 14             	add    $0x14,%esp
c0025069:	5b                   	pop    %ebx
c002506a:	5e                   	pop    %esi
c002506b:	c3                   	ret    

c002506c <input_full>:
/* Returns true if the input buffer is full,
   false otherwise.
   Interrupts must be off. */
bool
input_full (void) 
{
c002506c:	83 ec 0c             	sub    $0xc,%esp
  ASSERT (intr_get_level () == INTR_OFF);
c002506f:	e8 a3 c1 ff ff       	call   c0021217 <intr_get_level>
c0025074:	85 c0                	test   %eax,%eax
c0025076:	75 11                	jne    c0025089 <input_full+0x1d>
  return intq_full (&buffer);
c0025078:	83 ec 0c             	sub    $0xc,%esp
c002507b:	68 a0 82 03 c0       	push   $0xc00382a0
c0025080:	e8 8e 00 00 00       	call   c0025113 <intq_full>
}
c0025085:	83 c4 1c             	add    $0x1c,%esp
c0025088:	c3                   	ret    
  ASSERT (intr_get_level () == INTR_OFF);
c0025089:	83 ec 0c             	sub    $0xc,%esp
c002508c:	68 20 d1 02 c0       	push   $0xc002d120
c0025091:	68 9f cd 02 c0       	push   $0xc002cd9f
c0025096:	68 2c c0 02 c0       	push   $0xc002c02c
c002509b:	6a 32                	push   $0x32
c002509d:	68 bc e2 02 c0       	push   $0xc002e2bc
c00250a2:	e8 68 27 00 00       	call   c002780f <debug_panic>

c00250a7 <intq_init>:
static void signal (struct intq *q, struct thread **waiter);

/* Initializes interrupt queue Q. */
void
intq_init (struct intq *q) 
{
c00250a7:	53                   	push   %ebx
c00250a8:	83 ec 14             	sub    $0x14,%esp
c00250ab:	8b 5c 24 1c          	mov    0x1c(%esp),%ebx
  lock_init (&q->lock);
c00250af:	53                   	push   %ebx
c00250b0:	e8 00 d4 ff ff       	call   c00224b5 <lock_init>
  q->not_full = q->not_empty = NULL;
c00250b5:	c7 43 1c 00 00 00 00 	movl   $0x0,0x1c(%ebx)
c00250bc:	c7 43 18 00 00 00 00 	movl   $0x0,0x18(%ebx)
  q->head = q->tail = 0;
c00250c3:	c7 43 64 00 00 00 00 	movl   $0x0,0x64(%ebx)
c00250ca:	c7 43 60 00 00 00 00 	movl   $0x0,0x60(%ebx)
}
c00250d1:	83 c4 18             	add    $0x18,%esp
c00250d4:	5b                   	pop    %ebx
c00250d5:	c3                   	ret    

c00250d6 <intq_empty>:

/* Returns true if Q is empty, false otherwise. */
bool
intq_empty (const struct intq *q) 
{
c00250d6:	53                   	push   %ebx
c00250d7:	83 ec 08             	sub    $0x8,%esp
c00250da:	8b 5c 24 10          	mov    0x10(%esp),%ebx
  ASSERT (intr_get_level () == INTR_OFF);
c00250de:	e8 34 c1 ff ff       	call   c0021217 <intr_get_level>
c00250e3:	85 c0                	test   %eax,%eax
c00250e5:	75 0e                	jne    c00250f5 <intq_empty+0x1f>
  return q->head == q->tail;
c00250e7:	8b 43 64             	mov    0x64(%ebx),%eax
c00250ea:	39 43 60             	cmp    %eax,0x60(%ebx)
c00250ed:	0f 94 c0             	sete   %al
}
c00250f0:	83 c4 08             	add    $0x8,%esp
c00250f3:	5b                   	pop    %ebx
c00250f4:	c3                   	ret    
  ASSERT (intr_get_level () == INTR_OFF);
c00250f5:	83 ec 0c             	sub    $0xc,%esp
c00250f8:	68 20 d1 02 c0       	push   $0xc002d120
c00250fd:	68 9f cd 02 c0       	push   $0xc002cd9f
c0025102:	68 78 c0 02 c0       	push   $0xc002c078
c0025107:	6a 16                	push   $0x16
c0025109:	68 e7 e2 02 c0       	push   $0xc002e2e7
c002510e:	e8 fc 26 00 00       	call   c002780f <debug_panic>

c0025113 <intq_full>:

/* Returns true if Q is full, false otherwise. */
bool
intq_full (const struct intq *q) 
{
c0025113:	53                   	push   %ebx
c0025114:	83 ec 08             	sub    $0x8,%esp
c0025117:	8b 5c 24 10          	mov    0x10(%esp),%ebx
  ASSERT (intr_get_level () == INTR_OFF);
c002511b:	e8 f7 c0 ff ff       	call   c0021217 <intr_get_level>
c0025120:	85 c0                	test   %eax,%eax
c0025122:	75 16                	jne    c002513a <intq_full+0x27>

/* Returns the position after POS within an intq. */
static int
next (int pos) 
{
  return (pos + 1) % INTQ_BUFSIZE;
c0025124:	8b 43 60             	mov    0x60(%ebx),%eax
c0025127:	40                   	inc    %eax
c0025128:	25 3f 00 00 80       	and    $0x8000003f,%eax
c002512d:	78 29                	js     c0025158 <intq_full+0x45>
  return next (q->head) == q->tail;
c002512f:	3b 43 64             	cmp    0x64(%ebx),%eax
c0025132:	0f 94 c0             	sete   %al
}
c0025135:	83 c4 08             	add    $0x8,%esp
c0025138:	5b                   	pop    %ebx
c0025139:	c3                   	ret    
  ASSERT (intr_get_level () == INTR_OFF);
c002513a:	83 ec 0c             	sub    $0xc,%esp
c002513d:	68 20 d1 02 c0       	push   $0xc002d120
c0025142:	68 9f cd 02 c0       	push   $0xc002cd9f
c0025147:	68 6c c0 02 c0       	push   $0xc002c06c
c002514c:	6a 1e                	push   $0x1e
c002514e:	68 e7 e2 02 c0       	push   $0xc002e2e7
c0025153:	e8 b7 26 00 00       	call   c002780f <debug_panic>
  return (pos + 1) % INTQ_BUFSIZE;
c0025158:	48                   	dec    %eax
c0025159:	83 c8 c0             	or     $0xffffffc0,%eax
c002515c:	40                   	inc    %eax
c002515d:	eb d0                	jmp    c002512f <intq_full+0x1c>

c002515f <wait>:

/* WAITER must be the address of Q's not_empty or not_full
   member.  Waits until the given condition is true. */
static void
wait (struct intq *q UNUSED, struct thread **waiter) 
{
c002515f:	56                   	push   %esi
c0025160:	53                   	push   %ebx
c0025161:	83 ec 04             	sub    $0x4,%esp
c0025164:	89 c3                	mov    %eax,%ebx
c0025166:	89 d6                	mov    %edx,%esi
  ASSERT (!intr_context ());
c0025168:	e8 08 c3 ff ff       	call   c0021475 <intr_context>
c002516d:	84 c0                	test   %al,%al
c002516f:	75 39                	jne    c00251aa <wait+0x4b>
  ASSERT (intr_get_level () == INTR_OFF);
c0025171:	e8 a1 c0 ff ff       	call   c0021217 <intr_get_level>
c0025176:	85 c0                	test   %eax,%eax
c0025178:	75 4e                	jne    c00251c8 <wait+0x69>
  ASSERT ((waiter == &q->not_empty && intq_empty (q))
c002517a:	8d 43 1c             	lea    0x1c(%ebx),%eax
c002517d:	39 c6                	cmp    %eax,%esi
c002517f:	74 65                	je     c00251e6 <wait+0x87>
c0025181:	8d 43 18             	lea    0x18(%ebx),%eax
c0025184:	39 c6                	cmp    %eax,%esi
c0025186:	75 70                	jne    c00251f8 <wait+0x99>
c0025188:	83 ec 0c             	sub    $0xc,%esp
c002518b:	53                   	push   %ebx
c002518c:	e8 82 ff ff ff       	call   c0025113 <intq_full>
c0025191:	83 c4 10             	add    $0x10,%esp
c0025194:	84 c0                	test   %al,%al
c0025196:	74 60                	je     c00251f8 <wait+0x99>
          || (waiter == &q->not_full && intq_full (q)));

  *waiter = thread_current ();
c0025198:	e8 b2 b9 ff ff       	call   c0020b4f <thread_current>
c002519d:	89 06                	mov    %eax,(%esi)
  thread_block ();
c002519f:	e8 1d bd ff ff       	call   c0020ec1 <thread_block>
}
c00251a4:	83 c4 04             	add    $0x4,%esp
c00251a7:	5b                   	pop    %ebx
c00251a8:	5e                   	pop    %esi
c00251a9:	c3                   	ret    
  ASSERT (!intr_context ());
c00251aa:	83 ec 0c             	sub    $0xc,%esp
c00251ad:	68 cc d1 02 c0       	push   $0xc002d1cc
c00251b2:	68 9f cd 02 c0       	push   $0xc002cd9f
c00251b7:	68 58 c0 02 c0       	push   $0xc002c058
c00251bc:	6a 59                	push   $0x59
c00251be:	68 e7 e2 02 c0       	push   $0xc002e2e7
c00251c3:	e8 47 26 00 00       	call   c002780f <debug_panic>
  ASSERT (intr_get_level () == INTR_OFF);
c00251c8:	83 ec 0c             	sub    $0xc,%esp
c00251cb:	68 20 d1 02 c0       	push   $0xc002d120
c00251d0:	68 9f cd 02 c0       	push   $0xc002cd9f
c00251d5:	68 58 c0 02 c0       	push   $0xc002c058
c00251da:	6a 5a                	push   $0x5a
c00251dc:	68 e7 e2 02 c0       	push   $0xc002e2e7
c00251e1:	e8 29 26 00 00       	call   c002780f <debug_panic>
  ASSERT ((waiter == &q->not_empty && intq_empty (q))
c00251e6:	83 ec 0c             	sub    $0xc,%esp
c00251e9:	53                   	push   %ebx
c00251ea:	e8 e7 fe ff ff       	call   c00250d6 <intq_empty>
c00251ef:	83 c4 10             	add    $0x10,%esp
c00251f2:	84 c0                	test   %al,%al
c00251f4:	74 8b                	je     c0025181 <wait+0x22>
c00251f6:	eb a0                	jmp    c0025198 <wait+0x39>
c00251f8:	83 ec 0c             	sub    $0xc,%esp
c00251fb:	68 fc e2 02 c0       	push   $0xc002e2fc
c0025200:	68 9f cd 02 c0       	push   $0xc002cd9f
c0025205:	68 58 c0 02 c0       	push   $0xc002c058
c002520a:	6a 5c                	push   $0x5c
c002520c:	68 e7 e2 02 c0       	push   $0xc002e2e7
c0025211:	e8 f9 25 00 00       	call   c002780f <debug_panic>

c0025216 <signal>:
   member, and the associated condition must be true.  If a
   thread is waiting for the condition, wakes it up and resets
   the waiting thread. */
static void
signal (struct intq *q UNUSED, struct thread **waiter) 
{
c0025216:	56                   	push   %esi
c0025217:	53                   	push   %ebx
c0025218:	83 ec 04             	sub    $0x4,%esp
c002521b:	89 c6                	mov    %eax,%esi
c002521d:	89 d3                	mov    %edx,%ebx
  ASSERT (intr_get_level () == INTR_OFF);
c002521f:	e8 f3 bf ff ff       	call   c0021217 <intr_get_level>
c0025224:	85 c0                	test   %eax,%eax
c0025226:	75 3c                	jne    c0025264 <signal+0x4e>
  ASSERT ((waiter == &q->not_empty && !intq_empty (q))
c0025228:	8d 46 1c             	lea    0x1c(%esi),%eax
c002522b:	39 c3                	cmp    %eax,%ebx
c002522d:	74 53                	je     c0025282 <signal+0x6c>
c002522f:	8d 46 18             	lea    0x18(%esi),%eax
c0025232:	39 c3                	cmp    %eax,%ebx
c0025234:	75 5e                	jne    c0025294 <signal+0x7e>
c0025236:	83 ec 0c             	sub    $0xc,%esp
c0025239:	56                   	push   %esi
c002523a:	e8 d4 fe ff ff       	call   c0025113 <intq_full>
c002523f:	83 c4 10             	add    $0x10,%esp
c0025242:	84 c0                	test   %al,%al
c0025244:	75 4e                	jne    c0025294 <signal+0x7e>
          || (waiter == &q->not_full && !intq_full (q)));

  if (*waiter != NULL) 
c0025246:	8b 03                	mov    (%ebx),%eax
c0025248:	85 c0                	test   %eax,%eax
c002524a:	74 12                	je     c002525e <signal+0x48>
    {
      thread_unblock (*waiter);
c002524c:	83 ec 0c             	sub    $0xc,%esp
c002524f:	50                   	push   %eax
c0025250:	e8 57 b7 ff ff       	call   c00209ac <thread_unblock>
      *waiter = NULL;
c0025255:	c7 03 00 00 00 00    	movl   $0x0,(%ebx)
c002525b:	83 c4 10             	add    $0x10,%esp
    }
}
c002525e:	83 c4 04             	add    $0x4,%esp
c0025261:	5b                   	pop    %ebx
c0025262:	5e                   	pop    %esi
c0025263:	c3                   	ret    
  ASSERT (intr_get_level () == INTR_OFF);
c0025264:	83 ec 0c             	sub    $0xc,%esp
c0025267:	68 20 d1 02 c0       	push   $0xc002d120
c002526c:	68 9f cd 02 c0       	push   $0xc002cd9f
c0025271:	68 50 c0 02 c0       	push   $0xc002c050
c0025276:	6a 69                	push   $0x69
c0025278:	68 e7 e2 02 c0       	push   $0xc002e2e7
c002527d:	e8 8d 25 00 00       	call   c002780f <debug_panic>
  ASSERT ((waiter == &q->not_empty && !intq_empty (q))
c0025282:	83 ec 0c             	sub    $0xc,%esp
c0025285:	56                   	push   %esi
c0025286:	e8 4b fe ff ff       	call   c00250d6 <intq_empty>
c002528b:	83 c4 10             	add    $0x10,%esp
c002528e:	84 c0                	test   %al,%al
c0025290:	74 b4                	je     c0025246 <signal+0x30>
c0025292:	eb 9b                	jmp    c002522f <signal+0x19>
c0025294:	83 ec 0c             	sub    $0xc,%esp
c0025297:	68 58 e3 02 c0       	push   $0xc002e358
c002529c:	68 9f cd 02 c0       	push   $0xc002cd9f
c00252a1:	68 50 c0 02 c0       	push   $0xc002c050
c00252a6:	6a 6b                	push   $0x6b
c00252a8:	68 e7 e2 02 c0       	push   $0xc002e2e7
c00252ad:	e8 5d 25 00 00       	call   c002780f <debug_panic>

c00252b2 <intq_getc>:
{
c00252b2:	56                   	push   %esi
c00252b3:	53                   	push   %ebx
c00252b4:	83 ec 04             	sub    $0x4,%esp
c00252b7:	8b 5c 24 10          	mov    0x10(%esp),%ebx
  ASSERT (intr_get_level () == INTR_OFF);
c00252bb:	e8 57 bf ff ff       	call   c0021217 <intr_get_level>
c00252c0:	85 c0                	test   %eax,%eax
c00252c2:	75 3b                	jne    c00252ff <intq_getc+0x4d>
      wait (q, &q->not_empty);
c00252c4:	8d 73 1c             	lea    0x1c(%ebx),%esi
  while (intq_empty (q)) 
c00252c7:	83 ec 0c             	sub    $0xc,%esp
c00252ca:	53                   	push   %ebx
c00252cb:	e8 06 fe ff ff       	call   c00250d6 <intq_empty>
c00252d0:	83 c4 10             	add    $0x10,%esp
c00252d3:	84 c0                	test   %al,%al
c00252d5:	74 64                	je     c002533b <intq_getc+0x89>
      ASSERT (!intr_context ());
c00252d7:	e8 99 c1 ff ff       	call   c0021475 <intr_context>
c00252dc:	84 c0                	test   %al,%al
c00252de:	75 3d                	jne    c002531d <intq_getc+0x6b>
      lock_acquire (&q->lock);
c00252e0:	83 ec 0c             	sub    $0xc,%esp
c00252e3:	53                   	push   %ebx
c00252e4:	e8 4e d2 ff ff       	call   c0022537 <lock_acquire>
      wait (q, &q->not_empty);
c00252e9:	89 f2                	mov    %esi,%edx
c00252eb:	89 d8                	mov    %ebx,%eax
c00252ed:	e8 6d fe ff ff       	call   c002515f <wait>
      lock_release (&q->lock);
c00252f2:	89 1c 24             	mov    %ebx,(%esp)
c00252f5:	e8 62 d3 ff ff       	call   c002265c <lock_release>
c00252fa:	83 c4 10             	add    $0x10,%esp
c00252fd:	eb c8                	jmp    c00252c7 <intq_getc+0x15>
  ASSERT (intr_get_level () == INTR_OFF);
c00252ff:	83 ec 0c             	sub    $0xc,%esp
c0025302:	68 20 d1 02 c0       	push   $0xc002d120
c0025307:	68 9f cd 02 c0       	push   $0xc002cd9f
c002530c:	68 60 c0 02 c0       	push   $0xc002c060
c0025311:	6a 2a                	push   $0x2a
c0025313:	68 e7 e2 02 c0       	push   $0xc002e2e7
c0025318:	e8 f2 24 00 00       	call   c002780f <debug_panic>
      ASSERT (!intr_context ());
c002531d:	83 ec 0c             	sub    $0xc,%esp
c0025320:	68 cc d1 02 c0       	push   $0xc002d1cc
c0025325:	68 9f cd 02 c0       	push   $0xc002cd9f
c002532a:	68 60 c0 02 c0       	push   $0xc002c060
c002532f:	6a 2d                	push   $0x2d
c0025331:	68 e7 e2 02 c0       	push   $0xc002e2e7
c0025336:	e8 d4 24 00 00       	call   c002780f <debug_panic>
  byte = q->buf[q->tail];
c002533b:	8b 43 64             	mov    0x64(%ebx),%eax
c002533e:	0f b6 74 03 20       	movzbl 0x20(%ebx,%eax,1),%esi
  return (pos + 1) % INTQ_BUFSIZE;
c0025343:	40                   	inc    %eax
c0025344:	25 3f 00 00 80       	and    $0x8000003f,%eax
c0025349:	78 15                	js     c0025360 <intq_getc+0xae>
  q->tail = next (q->tail);
c002534b:	89 43 64             	mov    %eax,0x64(%ebx)
  signal (q, &q->not_full);
c002534e:	8d 53 18             	lea    0x18(%ebx),%edx
c0025351:	89 d8                	mov    %ebx,%eax
c0025353:	e8 be fe ff ff       	call   c0025216 <signal>
}
c0025358:	89 f0                	mov    %esi,%eax
c002535a:	83 c4 04             	add    $0x4,%esp
c002535d:	5b                   	pop    %ebx
c002535e:	5e                   	pop    %esi
c002535f:	c3                   	ret    
  return (pos + 1) % INTQ_BUFSIZE;
c0025360:	48                   	dec    %eax
c0025361:	83 c8 c0             	or     $0xffffffc0,%eax
c0025364:	40                   	inc    %eax
c0025365:	eb e4                	jmp    c002534b <intq_getc+0x99>

c0025367 <intq_putc>:
{
c0025367:	57                   	push   %edi
c0025368:	56                   	push   %esi
c0025369:	53                   	push   %ebx
c002536a:	8b 5c 24 10          	mov    0x10(%esp),%ebx
c002536e:	8b 7c 24 14          	mov    0x14(%esp),%edi
  ASSERT (intr_get_level () == INTR_OFF);
c0025372:	e8 a0 be ff ff       	call   c0021217 <intr_get_level>
c0025377:	85 c0                	test   %eax,%eax
c0025379:	75 3b                	jne    c00253b6 <intq_putc+0x4f>
      wait (q, &q->not_full);
c002537b:	8d 73 18             	lea    0x18(%ebx),%esi
  while (intq_full (q))
c002537e:	83 ec 0c             	sub    $0xc,%esp
c0025381:	53                   	push   %ebx
c0025382:	e8 8c fd ff ff       	call   c0025113 <intq_full>
c0025387:	83 c4 10             	add    $0x10,%esp
c002538a:	84 c0                	test   %al,%al
c002538c:	74 64                	je     c00253f2 <intq_putc+0x8b>
      ASSERT (!intr_context ());
c002538e:	e8 e2 c0 ff ff       	call   c0021475 <intr_context>
c0025393:	84 c0                	test   %al,%al
c0025395:	75 3d                	jne    c00253d4 <intq_putc+0x6d>
      lock_acquire (&q->lock);
c0025397:	83 ec 0c             	sub    $0xc,%esp
c002539a:	53                   	push   %ebx
c002539b:	e8 97 d1 ff ff       	call   c0022537 <lock_acquire>
      wait (q, &q->not_full);
c00253a0:	89 f2                	mov    %esi,%edx
c00253a2:	89 d8                	mov    %ebx,%eax
c00253a4:	e8 b6 fd ff ff       	call   c002515f <wait>
      lock_release (&q->lock);
c00253a9:	89 1c 24             	mov    %ebx,(%esp)
c00253ac:	e8 ab d2 ff ff       	call   c002265c <lock_release>
c00253b1:	83 c4 10             	add    $0x10,%esp
c00253b4:	eb c8                	jmp    c002537e <intq_putc+0x17>
  ASSERT (intr_get_level () == INTR_OFF);
c00253b6:	83 ec 0c             	sub    $0xc,%esp
c00253b9:	68 20 d1 02 c0       	push   $0xc002d120
c00253be:	68 9f cd 02 c0       	push   $0xc002cd9f
c00253c3:	68 44 c0 02 c0       	push   $0xc002c044
c00253c8:	6a 3f                	push   $0x3f
c00253ca:	68 e7 e2 02 c0       	push   $0xc002e2e7
c00253cf:	e8 3b 24 00 00       	call   c002780f <debug_panic>
      ASSERT (!intr_context ());
c00253d4:	83 ec 0c             	sub    $0xc,%esp
c00253d7:	68 cc d1 02 c0       	push   $0xc002d1cc
c00253dc:	68 9f cd 02 c0       	push   $0xc002cd9f
c00253e1:	68 44 c0 02 c0       	push   $0xc002c044
c00253e6:	6a 42                	push   $0x42
c00253e8:	68 e7 e2 02 c0       	push   $0xc002e2e7
c00253ed:	e8 1d 24 00 00       	call   c002780f <debug_panic>
  q->buf[q->head] = byte;
c00253f2:	8b 43 60             	mov    0x60(%ebx),%eax
c00253f5:	89 f9                	mov    %edi,%ecx
c00253f7:	88 4c 03 20          	mov    %cl,0x20(%ebx,%eax,1)
  return (pos + 1) % INTQ_BUFSIZE;
c00253fb:	40                   	inc    %eax
c00253fc:	25 3f 00 00 80       	and    $0x8000003f,%eax
c0025401:	78 11                	js     c0025414 <intq_putc+0xad>
  q->head = next (q->head);
c0025403:	89 43 60             	mov    %eax,0x60(%ebx)
  signal (q, &q->not_empty);
c0025406:	8d 53 1c             	lea    0x1c(%ebx),%edx
c0025409:	89 d8                	mov    %ebx,%eax
c002540b:	e8 06 fe ff ff       	call   c0025216 <signal>
}
c0025410:	5b                   	pop    %ebx
c0025411:	5e                   	pop    %esi
c0025412:	5f                   	pop    %edi
c0025413:	c3                   	ret    
  return (pos + 1) % INTQ_BUFSIZE;
c0025414:	48                   	dec    %eax
c0025415:	83 c8 c0             	or     $0xffffffc0,%eax
c0025418:	40                   	inc    %eax
c0025419:	eb e8                	jmp    c0025403 <intq_putc+0x9c>

c002541b <rtc_get_time>:

/* Returns number of seconds since Unix epoch of January 1,
   1970. */
time_t
rtc_get_time (void)
{
c002541b:	55                   	push   %ebp
c002541c:	57                   	push   %edi
c002541d:	56                   	push   %esi
c002541e:	53                   	push   %ebx
c002541f:	83 ec 18             	sub    $0x18,%esp
  asm volatile ("outb %b0, %w1" : : "a" (data), "Nd" (port));
c0025422:	bf 00 00 00 00       	mov    $0x0,%edi
c0025427:	89 f8                	mov    %edi,%eax
c0025429:	e6 70                	out    %al,$0x70
  asm volatile ("inb %w1, %b0" : "=a" (data) : "Nd" (port));
c002542b:	e4 71                	in     $0x71,%al
c002542d:	88 c2                	mov    %al,%dl
  asm volatile ("outb %b0, %w1" : : "a" (data), "Nd" (port));
c002542f:	b0 02                	mov    $0x2,%al
c0025431:	e6 70                	out    %al,$0x70
  asm volatile ("inb %w1, %b0" : "=a" (data) : "Nd" (port));
c0025433:	e4 71                	in     $0x71,%al
c0025435:	88 04 24             	mov    %al,(%esp)
  asm volatile ("outb %b0, %w1" : : "a" (data), "Nd" (port));
c0025438:	b0 04                	mov    $0x4,%al
c002543a:	e6 70                	out    %al,$0x70
  asm volatile ("inb %w1, %b0" : "=a" (data) : "Nd" (port));
c002543c:	e4 71                	in     $0x71,%al
c002543e:	88 44 24 13          	mov    %al,0x13(%esp)
  asm volatile ("outb %b0, %w1" : : "a" (data), "Nd" (port));
c0025442:	b0 07                	mov    $0x7,%al
c0025444:	e6 70                	out    %al,$0x70
  asm volatile ("inb %w1, %b0" : "=a" (data) : "Nd" (port));
c0025446:	e4 71                	in     $0x71,%al
c0025448:	89 c5                	mov    %eax,%ebp
  asm volatile ("outb %b0, %w1" : : "a" (data), "Nd" (port));
c002544a:	b0 08                	mov    $0x8,%al
c002544c:	e6 70                	out    %al,$0x70
  asm volatile ("inb %w1, %b0" : "=a" (data) : "Nd" (port));
c002544e:	e4 71                	in     $0x71,%al
c0025450:	88 c3                	mov    %al,%bl
  asm volatile ("outb %b0, %w1" : : "a" (data), "Nd" (port));
c0025452:	b0 09                	mov    $0x9,%al
c0025454:	e6 70                	out    %al,$0x70
  asm volatile ("inb %w1, %b0" : "=a" (data) : "Nd" (port));
c0025456:	e4 71                	in     $0x71,%al
c0025458:	89 c6                	mov    %eax,%esi
  asm volatile ("outb %b0, %w1" : : "a" (data), "Nd" (port));
c002545a:	89 f8                	mov    %edi,%eax
c002545c:	e6 70                	out    %al,$0x70
  asm volatile ("inb %w1, %b0" : "=a" (data) : "Nd" (port));
c002545e:	e4 71                	in     $0x71,%al

/* Returns the integer value of the given BCD byte. */
static int
bcd_to_bin (uint8_t x)
{
  return (x & 0x0f) + ((x >> 4) * 10);
c0025460:	88 c1                	mov    %al,%cl
c0025462:	c0 e9 04             	shr    $0x4,%cl
c0025465:	0f b6 c9             	movzbl %cl,%ecx
c0025468:	8d 0c 89             	lea    (%ecx,%ecx,4),%ecx
c002546b:	01 c9                	add    %ecx,%ecx
c002546d:	83 e0 0f             	and    $0xf,%eax
c0025470:	01 c8                	add    %ecx,%eax
c0025472:	88 d1                	mov    %dl,%cl
c0025474:	c0 e9 04             	shr    $0x4,%cl
c0025477:	0f b6 c9             	movzbl %cl,%ecx
c002547a:	8d 0c 89             	lea    (%ecx,%ecx,4),%ecx
c002547d:	01 c9                	add    %ecx,%ecx
c002547f:	83 e2 0f             	and    $0xf,%edx
c0025482:	01 ca                	add    %ecx,%edx
  while (sec != bcd_to_bin (cmos_read (RTC_REG_SEC)));
c0025484:	39 d0                	cmp    %edx,%eax
c0025486:	75 9f                	jne    c0025427 <rtc_get_time+0xc>
  return (x & 0x0f) + ((x >> 4) * 10);
c0025488:	89 f2                	mov    %esi,%edx
c002548a:	c0 ea 04             	shr    $0x4,%dl
c002548d:	0f b6 d2             	movzbl %dl,%edx
c0025490:	8d 14 92             	lea    (%edx,%edx,4),%edx
c0025493:	01 d2                	add    %edx,%edx
c0025495:	83 e6 0f             	and    $0xf,%esi
c0025498:	01 d6                	add    %edx,%esi
  if (year < 70)
c002549a:	83 fe 45             	cmp    $0x45,%esi
c002549d:	7f 03                	jg     c00254a2 <rtc_get_time+0x87>
    year += 100;
c002549f:	83 c6 64             	add    $0x64,%esi
  return (x & 0x0f) + ((x >> 4) * 10);
c00254a2:	88 da                	mov    %bl,%dl
c00254a4:	c0 ea 04             	shr    $0x4,%dl
c00254a7:	0f b6 d2             	movzbl %dl,%edx
c00254aa:	8d 14 92             	lea    (%edx,%edx,4),%edx
c00254ad:	01 d2                	add    %edx,%edx
c00254af:	83 e3 0f             	and    $0xf,%ebx
c00254b2:	01 d3                	add    %edx,%ebx
  year -= 70;
c00254b4:	8d 7e ba             	lea    -0x46(%esi),%edi
c00254b7:	89 7c 24 14          	mov    %edi,0x14(%esp)
  time = (year * 365 + (year - 1) / 4) * 24 * 60 * 60;
c00254bb:	83 ee 47             	sub    $0x47,%esi
c00254be:	89 f2                	mov    %esi,%edx
c00254c0:	85 f6                	test   %esi,%esi
c00254c2:	0f 88 de 00 00 00    	js     c00255a6 <rtc_get_time+0x18b>
c00254c8:	c1 fa 02             	sar    $0x2,%edx
c00254cb:	8b 7c 24 14          	mov    0x14(%esp),%edi
c00254cf:	8d 0c ff             	lea    (%edi,%edi,8),%ecx
c00254d2:	8d 0c cf             	lea    (%edi,%ecx,8),%ecx
c00254d5:	8d 0c 89             	lea    (%ecx,%ecx,4),%ecx
c00254d8:	01 ca                	add    %ecx,%edx
c00254da:	8d 0c 92             	lea    (%edx,%edx,4),%ecx
c00254dd:	8d 0c 8a             	lea    (%edx,%ecx,4),%ecx
c00254e0:	8d 3c ca             	lea    (%edx,%ecx,8),%edi
c00254e3:	c1 e7 02             	shl    $0x2,%edi
c00254e6:	29 d7                	sub    %edx,%edi
c00254e8:	c1 e7 07             	shl    $0x7,%edi
  for (i = 1; i <= mon; i++)
c00254eb:	85 db                	test   %ebx,%ebx
c00254ed:	7e 24                	jle    c0025513 <rtc_get_time+0xf8>
c00254ef:	be 01 00 00 00       	mov    $0x1,%esi
    time += days_per_month[i - 1] * 24 * 60 * 60;
c00254f4:	8b 0c b5 9c c0 02 c0 	mov    -0x3ffd3f64(,%esi,4),%ecx
c00254fb:	8d 14 89             	lea    (%ecx,%ecx,4),%edx
c00254fe:	8d 14 91             	lea    (%ecx,%edx,4),%edx
c0025501:	8d 14 d1             	lea    (%ecx,%edx,8),%edx
c0025504:	c1 e2 02             	shl    $0x2,%edx
c0025507:	29 ca                	sub    %ecx,%edx
c0025509:	c1 e2 07             	shl    $0x7,%edx
c002550c:	01 d7                	add    %edx,%edi
  for (i = 1; i <= mon; i++)
c002550e:	46                   	inc    %esi
c002550f:	39 de                	cmp    %ebx,%esi
c0025511:	7e e1                	jle    c00254f4 <rtc_get_time+0xd9>
  if (mon > 2 && year % 4 == 0)
c0025513:	83 fb 02             	cmp    $0x2,%ebx
c0025516:	7e 0d                	jle    c0025525 <rtc_get_time+0x10a>
c0025518:	f6 44 24 14 03       	testb  $0x3,0x14(%esp)
c002551d:	75 06                	jne    c0025525 <rtc_get_time+0x10a>
    time += 24 * 60 * 60;
c002551f:	81 c7 80 51 01 00    	add    $0x15180,%edi
  return (x & 0x0f) + ((x >> 4) * 10);
c0025525:	8a 5c 24 13          	mov    0x13(%esp),%bl
c0025529:	88 da                	mov    %bl,%dl
c002552b:	c0 ea 04             	shr    $0x4,%dl
c002552e:	0f b6 d2             	movzbl %dl,%edx
c0025531:	8d 0c 92             	lea    (%edx,%edx,4),%ecx
c0025534:	01 c9                	add    %ecx,%ecx
c0025536:	89 da                	mov    %ebx,%edx
c0025538:	83 e2 0f             	and    $0xf,%edx
c002553b:	01 ca                	add    %ecx,%edx
  time += hour * 60 * 60;
c002553d:	8d 0c 12             	lea    (%edx,%edx,1),%ecx
c0025540:	01 d1                	add    %edx,%ecx
c0025542:	01 c9                	add    %ecx,%ecx
c0025544:	01 d1                	add    %edx,%ecx
c0025546:	c1 e1 05             	shl    $0x5,%ecx
c0025549:	01 d1                	add    %edx,%ecx
c002554b:	c1 e1 04             	shl    $0x4,%ecx
  return (x & 0x0f) + ((x >> 4) * 10);
c002554e:	8a 14 24             	mov    (%esp),%dl
c0025551:	c0 ea 04             	shr    $0x4,%dl
c0025554:	0f b6 d2             	movzbl %dl,%edx
c0025557:	8d 14 92             	lea    (%edx,%edx,4),%edx
c002555a:	8d 1c 12             	lea    (%edx,%edx,1),%ebx
c002555d:	8b 14 24             	mov    (%esp),%edx
c0025560:	83 e2 0f             	and    $0xf,%edx
c0025563:	01 da                	add    %ebx,%edx
  time += min * 60;
c0025565:	8d 1c 12             	lea    (%edx,%edx,1),%ebx
c0025568:	01 da                	add    %ebx,%edx
c002556a:	8d 14 92             	lea    (%edx,%edx,4),%edx
  time += sec;
c002556d:	8d 14 91             	lea    (%ecx,%edx,4),%edx
c0025570:	01 d0                	add    %edx,%eax
  return (x & 0x0f) + ((x >> 4) * 10);
c0025572:	89 ea                	mov    %ebp,%edx
c0025574:	c0 ea 04             	shr    $0x4,%dl
c0025577:	0f b6 d2             	movzbl %dl,%edx
c002557a:	8d 14 92             	lea    (%edx,%edx,4),%edx
c002557d:	8d 0c 12             	lea    (%edx,%edx,1),%ecx
c0025580:	89 ea                	mov    %ebp,%edx
c0025582:	83 e2 0f             	and    $0xf,%edx
  time += (mday - 1) * 24 * 60 * 60;
c0025585:	8d 4c 11 ff          	lea    -0x1(%ecx,%edx,1),%ecx
c0025589:	8d 14 89             	lea    (%ecx,%ecx,4),%edx
c002558c:	8d 14 91             	lea    (%ecx,%edx,4),%edx
c002558f:	8d 14 d1             	lea    (%ecx,%edx,8),%edx
c0025592:	c1 e2 02             	shl    $0x2,%edx
c0025595:	29 ca                	sub    %ecx,%edx
c0025597:	c1 e2 07             	shl    $0x7,%edx
  time += sec;
c002559a:	01 d0                	add    %edx,%eax
c002559c:	01 f8                	add    %edi,%eax
}
c002559e:	83 c4 18             	add    $0x18,%esp
c00255a1:	5b                   	pop    %ebx
c00255a2:	5e                   	pop    %esi
c00255a3:	5f                   	pop    %edi
c00255a4:	5d                   	pop    %ebp
c00255a5:	c3                   	ret    
  time = (year * 365 + (year - 1) / 4) * 24 * 60 * 60;
c00255a6:	8d 56 03             	lea    0x3(%esi),%edx
c00255a9:	e9 1a ff ff ff       	jmp    c00254c8 <rtc_get_time+0xad>

c00255ae <shutdown_configure>:
/* Sets TYPE as the way that machine will shut down when Pintos
   execution is complete. */
void
shutdown_configure (enum shutdown_type type)
{
  how = type;
c00255ae:	8b 44 24 04          	mov    0x4(%esp),%eax
c00255b2:	a3 08 83 03 c0       	mov    %eax,0xc0038308
c00255b7:	c3                   	ret    

c00255b8 <shutdown_reboot>:
}

/* Reboots the machine via the keyboard controller. */
void
shutdown_reboot (void)
{
c00255b8:	56                   	push   %esi
c00255b9:	53                   	push   %ebx
c00255ba:	83 ec 10             	sub    $0x10,%esp
  printf ("Rebooting...\n");
c00255bd:	68 b3 e3 02 c0       	push   $0xc002e3b3
c00255c2:	e8 96 3c 00 00       	call   c002925d <puts>
c00255c7:	83 c4 10             	add    $0x10,%esp
  asm volatile ("outb %b0, %w1" : : "a" (data), "Nd" (port));
c00255ca:	be fe ff ff ff       	mov    $0xfffffffe,%esi
c00255cf:	eb 1f                	jmp    c00255f0 <shutdown_reboot+0x38>
          if ((inb (CONTROL_REG) & 0x02) == 0)
            break;
          timer_udelay (2);
        }

      timer_udelay (50);
c00255d1:	83 ec 08             	sub    $0x8,%esp
c00255d4:	6a 00                	push   $0x0
c00255d6:	6a 32                	push   $0x32
c00255d8:	e8 0b e0 ff ff       	call   c00235e8 <timer_udelay>
c00255dd:	89 f0                	mov    %esi,%eax
c00255df:	e6 64                	out    %al,$0x64

      /* Pulse bit 0 of the output port P2 of the keyboard controller.
       * This will reset the CPU. */
      outb (CONTROL_REG, 0xfe);
      timer_udelay (50);
c00255e1:	83 c4 08             	add    $0x8,%esp
c00255e4:	6a 00                	push   $0x0
c00255e6:	6a 32                	push   $0x32
c00255e8:	e8 fb df ff ff       	call   c00235e8 <timer_udelay>
    {
c00255ed:	83 c4 10             	add    $0x10,%esp
  asm volatile ("inb %w1, %b0" : "=a" (data) : "Nd" (port));
c00255f0:	e4 64                	in     $0x64,%al
          if ((inb (CONTROL_REG) & 0x02) == 0)
c00255f2:	a8 02                	test   $0x2,%al
c00255f4:	74 db                	je     c00255d1 <shutdown_reboot+0x19>
          timer_udelay (2);
c00255f6:	83 ec 08             	sub    $0x8,%esp
c00255f9:	6a 00                	push   $0x0
c00255fb:	6a 02                	push   $0x2
c00255fd:	e8 e6 df ff ff       	call   c00235e8 <timer_udelay>
c0025602:	83 c4 10             	add    $0x10,%esp
c0025605:	bb ff ff 00 00       	mov    $0xffff,%ebx
c002560a:	e4 64                	in     $0x64,%al
          if ((inb (CONTROL_REG) & 0x02) == 0)
c002560c:	a8 02                	test   $0x2,%al
c002560e:	74 c1                	je     c00255d1 <shutdown_reboot+0x19>
          timer_udelay (2);
c0025610:	83 ec 08             	sub    $0x8,%esp
c0025613:	6a 00                	push   $0x0
c0025615:	6a 02                	push   $0x2
c0025617:	e8 cc df ff ff       	call   c00235e8 <timer_udelay>
      for (i = 0; i < 0x10000; i++)
c002561c:	83 c4 10             	add    $0x10,%esp
c002561f:	4b                   	dec    %ebx
c0025620:	75 e8                	jne    c002560a <shutdown_reboot+0x52>
c0025622:	eb ad                	jmp    c00255d1 <shutdown_reboot+0x19>

c0025624 <shutdown_power_off>:

/* Powers down the machine we're running on,
   as long as we're running on Bochs or QEMU. */
void
shutdown_power_off (void)
{
c0025624:	57                   	push   %edi
c0025625:	56                   	push   %esi
c0025626:	83 ec 14             	sub    $0x14,%esp
  const char s[] = "Shutdown";
c0025629:	8d 7c 24 07          	lea    0x7(%esp),%edi
c002562d:	be e1 e3 02 c0       	mov    $0xc002e3e1,%esi
c0025632:	b9 09 00 00 00       	mov    $0x9,%ecx
c0025637:	f3 a4                	rep movsb %ds:(%esi),%es:(%edi)

/* Print statistics about Pintos execution. */
static void
print_stats (void)
{
  timer_print_stats ();
c0025639:	e8 dc df ff ff       	call   c002361a <timer_print_stats>
  thread_print_stats ();
c002563e:	e8 3c b3 ff ff       	call   c002097f <thread_print_stats>
#ifdef FILESYS
  block_print_stats ();
#endif
  console_print_stats ();
c0025643:	e8 c4 3b 00 00       	call   c002920c <console_print_stats>
  kbd_print_stats ();
c0025648:	e8 de e1 ff ff       	call   c002382b <kbd_print_stats>
  printf ("Powering off...\n");
c002564d:	83 ec 0c             	sub    $0xc,%esp
c0025650:	68 c0 e3 02 c0       	push   $0xc002e3c0
c0025655:	e8 03 3c 00 00       	call   c002925d <puts>
  serial_flush ();
c002565a:	e8 b3 e6 ff ff       	call   c0023d12 <serial_flush>
  asm volatile ("outw %w0, %w1" : : "a" (data), "Nd" (port));
c002565f:	ba 04 b0 ff ff       	mov    $0xffffb004,%edx
c0025664:	b8 00 20 00 00       	mov    $0x2000,%eax
c0025669:	66 ef                	out    %ax,(%dx)
  for (p = s; *p != '\0'; p++)
c002566b:	8a 44 24 17          	mov    0x17(%esp),%al
c002566f:	83 c4 10             	add    $0x10,%esp
c0025672:	84 c0                	test   %al,%al
c0025674:	74 11                	je     c0025687 <shutdown_power_off+0x63>
c0025676:	8d 4c 24 07          	lea    0x7(%esp),%ecx
  asm volatile ("outb %b0, %w1" : : "a" (data), "Nd" (port));
c002567a:	ba 00 89 ff ff       	mov    $0xffff8900,%edx
c002567f:	ee                   	out    %al,(%dx)
c0025680:	41                   	inc    %ecx
c0025681:	8a 01                	mov    (%ecx),%al
c0025683:	84 c0                	test   %al,%al
c0025685:	75 f8                	jne    c002567f <shutdown_power_off+0x5b>
c0025687:	ba 01 05 00 00       	mov    $0x501,%edx
c002568c:	b0 31                	mov    $0x31,%al
c002568e:	ee                   	out    %al,(%dx)
  asm volatile ("cli; hlt" : : : "memory");
c002568f:	fa                   	cli    
c0025690:	f4                   	hlt    
  printf ("still running...\n");
c0025691:	83 ec 0c             	sub    $0xc,%esp
c0025694:	68 d0 e3 02 c0       	push   $0xc002e3d0
c0025699:	e8 bf 3b 00 00       	call   c002925d <puts>
c002569e:	83 c4 10             	add    $0x10,%esp
c00256a1:	eb fe                	jmp    c00256a1 <shutdown_power_off+0x7d>

c00256a3 <shutdown>:
{
c00256a3:	83 ec 0c             	sub    $0xc,%esp
  switch (how)
c00256a6:	a1 08 83 03 c0       	mov    0xc0038308,%eax
c00256ab:	83 f8 01             	cmp    $0x1,%eax
c00256ae:	74 09                	je     c00256b9 <shutdown+0x16>
c00256b0:	83 f8 02             	cmp    $0x2,%eax
c00256b3:	74 09                	je     c00256be <shutdown+0x1b>
}
c00256b5:	83 c4 0c             	add    $0xc,%esp
c00256b8:	c3                   	ret    
      shutdown_power_off ();
c00256b9:	e8 66 ff ff ff       	call   c0025624 <shutdown_power_off>
      shutdown_reboot ();
c00256be:	e8 f5 fe ff ff       	call   c00255b8 <shutdown_reboot>

c00256c3 <speaker_off>:

/* Turn off the PC speaker, by disconnecting the timer channel's
   output from the speaker. */
void
speaker_off (void)
{
c00256c3:	83 ec 0c             	sub    $0xc,%esp
  enum intr_level old_level = intr_disable ();
c00256c6:	e8 89 bb ff ff       	call   c0021254 <intr_disable>
c00256cb:	89 c2                	mov    %eax,%edx
  asm volatile ("inb %w1, %b0" : "=a" (data) : "Nd" (port));
c00256cd:	e4 61                	in     $0x61,%al
  asm volatile ("outb %b0, %w1" : : "a" (data), "Nd" (port));
c00256cf:	83 e0 fc             	and    $0xfffffffc,%eax
c00256d2:	e6 61                	out    %al,$0x61
  outb (SPEAKER_PORT_GATE, inb (SPEAKER_PORT_GATE) & ~SPEAKER_GATE_ENABLE);
  intr_set_level (old_level);
c00256d4:	83 ec 0c             	sub    $0xc,%esp
c00256d7:	52                   	push   %edx
c00256d8:	e8 7e bb ff ff       	call   c002125b <intr_set_level>
}
c00256dd:	83 c4 1c             	add    $0x1c,%esp
c00256e0:	c3                   	ret    

c00256e1 <speaker_on>:
{
c00256e1:	56                   	push   %esi
c00256e2:	53                   	push   %ebx
c00256e3:	83 ec 04             	sub    $0x4,%esp
c00256e6:	8b 5c 24 10          	mov    0x10(%esp),%ebx
  if (frequency >= 20 && frequency <= 20000)
c00256ea:	8d 43 ec             	lea    -0x14(%ebx),%eax
c00256ed:	3d 0c 4e 00 00       	cmp    $0x4e0c,%eax
c00256f2:	76 0b                	jbe    c00256ff <speaker_on+0x1e>
      speaker_off ();
c00256f4:	e8 ca ff ff ff       	call   c00256c3 <speaker_off>
}
c00256f9:	83 c4 04             	add    $0x4,%esp
c00256fc:	5b                   	pop    %ebx
c00256fd:	5e                   	pop    %esi
c00256fe:	c3                   	ret    
      enum intr_level old_level = intr_disable ();
c00256ff:	e8 50 bb ff ff       	call   c0021254 <intr_disable>
c0025704:	89 c6                	mov    %eax,%esi
      pit_configure_channel (2, 3, frequency);
c0025706:	83 ec 04             	sub    $0x4,%esp
c0025709:	53                   	push   %ebx
c002570a:	6a 03                	push   $0x3
c002570c:	6a 02                	push   $0x2
c002570e:	e8 65 da ff ff       	call   c0023178 <pit_configure_channel>
  asm volatile ("inb %w1, %b0" : "=a" (data) : "Nd" (port));
c0025713:	e4 61                	in     $0x61,%al
      outb (SPEAKER_PORT_GATE, inb (SPEAKER_PORT_GATE) | SPEAKER_GATE_ENABLE);
c0025715:	83 c8 03             	or     $0x3,%eax
  asm volatile ("outb %b0, %w1" : : "a" (data), "Nd" (port));
c0025718:	e6 61                	out    %al,$0x61
      intr_set_level (old_level);
c002571a:	89 34 24             	mov    %esi,(%esp)
c002571d:	e8 39 bb ff ff       	call   c002125b <intr_set_level>
c0025722:	83 c4 10             	add    $0x10,%esp
c0025725:	eb d2                	jmp    c00256f9 <speaker_on+0x18>

c0025727 <speaker_beep>:

/* Briefly beep the PC speaker. */
void
speaker_beep (void)
{
c0025727:	83 ec 0c             	sub    $0xc,%esp

     We can't just enable interrupts while we sleep.  For one
     thing, we get called (indirectly) from printf, which should
     always work, even during boot before we're ready to enable
     interrupts. */
  if (intr_get_level () == INTR_ON)
c002572a:	e8 e8 ba ff ff       	call   c0021217 <intr_get_level>
c002572f:	83 f8 01             	cmp    $0x1,%eax
c0025732:	74 04                	je     c0025738 <speaker_beep+0x11>
    {
      speaker_on (440);
      timer_msleep (250);
      speaker_off ();
    }
}
c0025734:	83 c4 0c             	add    $0xc,%esp
c0025737:	c3                   	ret    
      speaker_on (440);
c0025738:	83 ec 0c             	sub    $0xc,%esp
c002573b:	68 b8 01 00 00       	push   $0x1b8
c0025740:	e8 9c ff ff ff       	call   c00256e1 <speaker_on>
      timer_msleep (250);
c0025745:	83 c4 08             	add    $0x8,%esp
c0025748:	6a 00                	push   $0x0
c002574a:	68 fa 00 00 00       	push   $0xfa
c002574f:	e8 30 de ff ff       	call   c0023584 <timer_msleep>
      speaker_off ();
c0025754:	e8 6a ff ff ff       	call   c00256c3 <speaker_off>
c0025759:	83 c4 10             	add    $0x10,%esp
}
c002575c:	eb d6                	jmp    c0025734 <speaker_beep+0xd>

c002575e <debug_backtrace>:
   each of the functions we are nested within.  gdb or addr2line
   may be applied to kernel.o to translate these into file names,
   line numbers, and function names.  */
void
debug_backtrace (void) 
{
c002575e:	55                   	push   %ebp
c002575f:	89 e5                	mov    %esp,%ebp
c0025761:	53                   	push   %ebx
c0025762:	83 ec 0c             	sub    $0xc,%esp
  static bool explained;
  void **frame;
  
  printf ("Call stack: %p", __builtin_return_address (0));
c0025765:	ff 75 04             	pushl  0x4(%ebp)
c0025768:	68 ea e3 02 c0       	push   $0xc002e3ea
c002576d:	e8 ef 05 00 00       	call   c0025d61 <printf>
  for (frame = __builtin_frame_address (1);
c0025772:	8b 5d 00             	mov    0x0(%ebp),%ebx
c0025775:	83 c4 10             	add    $0x10,%esp
c0025778:	81 fb ff 0f 00 00    	cmp    $0xfff,%ebx
c002577e:	76 27                	jbe    c00257a7 <debug_backtrace+0x49>
       (uintptr_t) frame >= 0x1000 && frame[0] != NULL;
c0025780:	83 3b 00             	cmpl   $0x0,(%ebx)
c0025783:	74 22                	je     c00257a7 <debug_backtrace+0x49>
       frame = frame[0]) 
    printf (" %p", frame[1]);
c0025785:	83 ec 08             	sub    $0x8,%esp
c0025788:	ff 73 04             	pushl  0x4(%ebx)
c002578b:	68 f5 e3 02 c0       	push   $0xc002e3f5
c0025790:	e8 cc 05 00 00       	call   c0025d61 <printf>
       frame = frame[0]) 
c0025795:	8b 1b                	mov    (%ebx),%ebx
  for (frame = __builtin_frame_address (1);
c0025797:	83 c4 10             	add    $0x10,%esp
c002579a:	81 fb ff 0f 00 00    	cmp    $0xfff,%ebx
c00257a0:	76 05                	jbe    c00257a7 <debug_backtrace+0x49>
       (uintptr_t) frame >= 0x1000 && frame[0] != NULL;
c00257a2:	83 3b 00             	cmpl   $0x0,(%ebx)
c00257a5:	75 de                	jne    c0025785 <debug_backtrace+0x27>
  printf (".\n");
c00257a7:	83 ec 0c             	sub    $0xc,%esp
c00257aa:	68 83 df 02 c0       	push   $0xc002df83
c00257af:	e8 a9 3a 00 00       	call   c002925d <puts>

  if (!explained) 
c00257b4:	83 c4 10             	add    $0x10,%esp
c00257b7:	80 3d 0c 83 03 c0 00 	cmpb   $0x0,0xc003830c
c00257be:	74 05                	je     c00257c5 <debug_backtrace+0x67>
      explained = true;
      printf ("The `backtrace' program can make call stacks useful.\n"
              "Read \"Backtraces\" in the \"Debugging Tools\" chapter\n"
              "of the Pintos documentation for more information.\n");
    }
}
c00257c0:	8b 5d fc             	mov    -0x4(%ebp),%ebx
c00257c3:	c9                   	leave  
c00257c4:	c3                   	ret    
      explained = true;
c00257c5:	c6 05 0c 83 03 c0 01 	movb   $0x1,0xc003830c
      printf ("The `backtrace' program can make call stacks useful.\n"
c00257cc:	83 ec 0c             	sub    $0xc,%esp
c00257cf:	68 fc e3 02 c0       	push   $0xc002e3fc
c00257d4:	e8 84 3a 00 00       	call   c002925d <puts>
c00257d9:	83 c4 10             	add    $0x10,%esp
}
c00257dc:	eb e2                	jmp    c00257c0 <debug_backtrace+0x62>

c00257de <random_init>:
}

/* Initializes or reinitializes the PRNG with the given SEED. */
void
random_init (unsigned seed)
{
c00257de:	56                   	push   %esi
c00257df:	53                   	push   %ebx
  uint8_t *seedp = (uint8_t *) &seed;
  int i;
  uint8_t j;

  for (i = 0; i < 256; i++) 
c00257e0:	b8 00 00 00 00       	mov    $0x0,%eax
    s[i] = i;
c00257e5:	88 80 40 83 03 c0    	mov    %al,-0x3ffc7cc0(%eax)
  for (i = 0; i < 256; i++) 
c00257eb:	40                   	inc    %eax
c00257ec:	3d 00 01 00 00       	cmp    $0x100,%eax
c00257f1:	75 f2                	jne    c00257e5 <random_init+0x7>
c00257f3:	be 00 00 00 00       	mov    $0x0,%esi
c00257f8:	b8 00 00 00 00       	mov    $0x0,%eax
  for (i = j = 0; i < 256; i++) 
    {
      j += s[i] + seedp[i % sizeof seed];
c00257fd:	89 c1                	mov    %eax,%ecx
c00257ff:	83 e1 03             	and    $0x3,%ecx
c0025802:	8a 98 40 83 03 c0    	mov    -0x3ffc7cc0(%eax),%bl
c0025808:	88 da                	mov    %bl,%dl
c002580a:	02 54 0c 0c          	add    0xc(%esp,%ecx,1),%dl
c002580e:	88 d1                	mov    %dl,%cl
c0025810:	01 ce                	add    %ecx,%esi
      swap_byte (s + i, s + j);
c0025812:	89 f2                	mov    %esi,%edx
c0025814:	0f b6 ca             	movzbl %dl,%ecx
  *a = *b;
c0025817:	8a 91 40 83 03 c0    	mov    -0x3ffc7cc0(%ecx),%dl
c002581d:	88 90 40 83 03 c0    	mov    %dl,-0x3ffc7cc0(%eax)
  *b = t;
c0025823:	88 99 40 83 03 c0    	mov    %bl,-0x3ffc7cc0(%ecx)
  for (i = j = 0; i < 256; i++) 
c0025829:	40                   	inc    %eax
c002582a:	3d 00 01 00 00       	cmp    $0x100,%eax
c002582f:	75 cc                	jne    c00257fd <random_init+0x1f>
    }

  s_i = s_j = 0;
c0025831:	c6 05 21 83 03 c0 00 	movb   $0x0,0xc0038321
c0025838:	c6 05 22 83 03 c0 00 	movb   $0x0,0xc0038322
  inited = true;
c002583f:	c6 05 20 83 03 c0 01 	movb   $0x1,0xc0038320
}
c0025846:	5b                   	pop    %ebx
c0025847:	5e                   	pop    %esi
c0025848:	c3                   	ret    

c0025849 <random_bytes>:

/* Writes SIZE random bytes into BUF. */
void
random_bytes (void *buf_, size_t size) 
{
c0025849:	55                   	push   %ebp
c002584a:	57                   	push   %edi
c002584b:	56                   	push   %esi
c002584c:	53                   	push   %ebx
c002584d:	83 ec 04             	sub    $0x4,%esp
c0025850:	8b 7c 24 1c          	mov    0x1c(%esp),%edi
  uint8_t *buf;

  if (!inited)
c0025854:	80 3d 20 83 03 c0 00 	cmpb   $0x0,0xc0038320
c002585b:	0f 84 8c 00 00 00    	je     c00258ed <random_bytes+0xa4>
    random_init (0);

  for (buf = buf_; size-- > 0; buf++)
c0025861:	8d 6f ff             	lea    -0x1(%edi),%ebp
c0025864:	85 ff                	test   %edi,%edi
c0025866:	74 7d                	je     c00258e5 <random_bytes+0x9c>
c0025868:	0f b6 35 21 83 03 c0 	movzbl 0xc0038321,%esi
c002586f:	a0 22 83 03 c0       	mov    0xc0038322,%al
c0025874:	40                   	inc    %eax
c0025875:	88 44 24 03          	mov    %al,0x3(%esp)
c0025879:	03 7c 24 18          	add    0x18(%esp),%edi
c002587d:	88 44 24 01          	mov    %al,0x1(%esp)
c0025881:	8b 4c 24 18          	mov    0x18(%esp),%ecx
    {
      uint8_t s_k;
      
      s_i++;
      s_j += s[s_i];
c0025885:	0f b6 54 24 01       	movzbl 0x1(%esp),%edx
c002588a:	89 f3                	mov    %esi,%ebx
c002588c:	02 9a 40 83 03 c0    	add    -0x3ffc7cc0(%edx),%bl
c0025892:	89 de                	mov    %ebx,%esi
      swap_byte (s + s_i, s + s_j);
c0025894:	0f b6 c3             	movzbl %bl,%eax
  uint8_t t = *a;
c0025897:	8a 9a 40 83 03 c0    	mov    -0x3ffc7cc0(%edx),%bl
c002589d:	88 5c 24 02          	mov    %bl,0x2(%esp)
  *a = *b;
c00258a1:	8a 98 40 83 03 c0    	mov    -0x3ffc7cc0(%eax),%bl
c00258a7:	88 9a 40 83 03 c0    	mov    %bl,-0x3ffc7cc0(%edx)
  *b = t;
c00258ad:	8a 5c 24 02          	mov    0x2(%esp),%bl
c00258b1:	88 98 40 83 03 c0    	mov    %bl,-0x3ffc7cc0(%eax)

      s_k = s[s_i] + s[s_j];
c00258b7:	88 d8                	mov    %bl,%al
c00258b9:	02 82 40 83 03 c0    	add    -0x3ffc7cc0(%edx),%al
      *buf = s[s_k];
c00258bf:	0f b6 c0             	movzbl %al,%eax
c00258c2:	8a 90 40 83 03 c0    	mov    -0x3ffc7cc0(%eax),%dl
c00258c8:	88 11                	mov    %dl,(%ecx)
  for (buf = buf_; size-- > 0; buf++)
c00258ca:	41                   	inc    %ecx
c00258cb:	fe 44 24 01          	incb   0x1(%esp)
c00258cf:	39 f9                	cmp    %edi,%ecx
c00258d1:	75 b2                	jne    c0025885 <random_bytes+0x3c>
c00258d3:	8a 44 24 03          	mov    0x3(%esp),%al
c00258d7:	01 e8                	add    %ebp,%eax
c00258d9:	a2 22 83 03 c0       	mov    %al,0xc0038322
c00258de:	89 f0                	mov    %esi,%eax
c00258e0:	a2 21 83 03 c0       	mov    %al,0xc0038321
    }
}
c00258e5:	83 c4 04             	add    $0x4,%esp
c00258e8:	5b                   	pop    %ebx
c00258e9:	5e                   	pop    %esi
c00258ea:	5f                   	pop    %edi
c00258eb:	5d                   	pop    %ebp
c00258ec:	c3                   	ret    
    random_init (0);
c00258ed:	6a 00                	push   $0x0
c00258ef:	e8 ea fe ff ff       	call   c00257de <random_init>
c00258f4:	83 c4 04             	add    $0x4,%esp
c00258f7:	e9 65 ff ff ff       	jmp    c0025861 <random_bytes+0x18>

c00258fc <random_ulong>:
/* Returns a pseudo-random unsigned long.
   Use random_ulong() % n to obtain a random number in the range
   0...n (exclusive). */
unsigned long
random_ulong (void) 
{
c00258fc:	83 ec 10             	sub    $0x10,%esp
  unsigned long ul;
  random_bytes (&ul, sizeof ul);
c00258ff:	6a 04                	push   $0x4
c0025901:	8d 44 24 10          	lea    0x10(%esp),%eax
c0025905:	50                   	push   %eax
c0025906:	e8 3e ff ff ff       	call   c0025849 <random_bytes>
  return ul;
}
c002590b:	8b 44 24 14          	mov    0x14(%esp),%eax
c002590f:	83 c4 18             	add    $0x18,%esp
c0025912:	c3                   	ret    

c0025913 <vsnprintf_helper>:
}

/* Helper function for vsnprintf(). */
static void
vsnprintf_helper (char ch, void *aux_)
{
c0025913:	53                   	push   %ebx
c0025914:	8b 5c 24 08          	mov    0x8(%esp),%ebx
c0025918:	8b 44 24 0c          	mov    0xc(%esp),%eax
  struct vsnprintf_aux *aux = aux_;

  if (aux->length++ < aux->max_length)
c002591c:	8b 50 04             	mov    0x4(%eax),%edx
c002591f:	8d 4a 01             	lea    0x1(%edx),%ecx
c0025922:	89 48 04             	mov    %ecx,0x4(%eax)
c0025925:	3b 50 08             	cmp    0x8(%eax),%edx
c0025928:	7d 09                	jge    c0025933 <vsnprintf_helper+0x20>
    *aux->p++ = ch;
c002592a:	8b 10                	mov    (%eax),%edx
c002592c:	8d 4a 01             	lea    0x1(%edx),%ecx
c002592f:	89 08                	mov    %ecx,(%eax)
c0025931:	88 1a                	mov    %bl,(%edx)
}
c0025933:	5b                   	pop    %ebx
c0025934:	c3                   	ret    

c0025935 <output_dup>:
}

/* Writes CH to OUTPUT with auxiliary data AUX, CNT times. */
static void
output_dup (char ch, size_t cnt, void (*output) (char, void *), void *aux) 
{
c0025935:	55                   	push   %ebp
c0025936:	57                   	push   %edi
c0025937:	56                   	push   %esi
c0025938:	53                   	push   %ebx
c0025939:	83 ec 0c             	sub    $0xc,%esp
c002593c:	8b 7c 24 20          	mov    0x20(%esp),%edi
  while (cnt-- > 0)
c0025940:	85 d2                	test   %edx,%edx
c0025942:	74 18                	je     c002595c <output_dup+0x27>
c0025944:	8d 5a ff             	lea    -0x1(%edx),%ebx
c0025947:	89 cd                	mov    %ecx,%ebp
    output (ch, aux);
c0025949:	0f be f0             	movsbl %al,%esi
c002594c:	83 ec 08             	sub    $0x8,%esp
c002594f:	57                   	push   %edi
c0025950:	56                   	push   %esi
c0025951:	ff d5                	call   *%ebp
  while (cnt-- > 0)
c0025953:	4b                   	dec    %ebx
c0025954:	83 c4 10             	add    $0x10,%esp
c0025957:	83 fb ff             	cmp    $0xffffffff,%ebx
c002595a:	75 f0                	jne    c002594c <output_dup+0x17>
}
c002595c:	83 c4 0c             	add    $0xc,%esp
c002595f:	5b                   	pop    %ebx
c0025960:	5e                   	pop    %esi
c0025961:	5f                   	pop    %edi
c0025962:	5d                   	pop    %ebp
c0025963:	c3                   	ret    

c0025964 <format_integer>:
{
c0025964:	55                   	push   %ebp
c0025965:	57                   	push   %edi
c0025966:	56                   	push   %esi
c0025967:	53                   	push   %ebx
c0025968:	83 ec 7c             	sub    $0x7c,%esp
c002596b:	89 c6                	mov    %eax,%esi
c002596d:	89 d7                	mov    %edx,%edi
c002596f:	8b 84 24 90 00 00 00 	mov    0x90(%esp),%eax
  if (is_signed) 
c0025976:	84 c9                	test   %cl,%cl
c0025978:	74 42                	je     c00259bc <format_integer+0x58>
      if (c->flags & PLUS)
c002597a:	8b 8c 24 98 00 00 00 	mov    0x98(%esp),%ecx
c0025981:	8b 11                	mov    (%ecx),%edx
c0025983:	f6 c2 02             	test   $0x2,%dl
c0025986:	74 10                	je     c0025998 <format_integer+0x34>
        sign = negative ? '-' : '+';
c0025988:	3c 01                	cmp    $0x1,%al
c002598a:	19 c0                	sbb    %eax,%eax
c002598c:	83 e0 fe             	and    $0xfffffffe,%eax
c002598f:	83 c0 2d             	add    $0x2d,%eax
c0025992:	89 44 24 24          	mov    %eax,0x24(%esp)
c0025996:	eb 2c                	jmp    c00259c4 <format_integer+0x60>
      else if (c->flags & SPACE)
c0025998:	f6 c2 04             	test   $0x4,%dl
c002599b:	74 10                	je     c00259ad <format_integer+0x49>
        sign = negative ? '-' : ' ';
c002599d:	3c 01                	cmp    $0x1,%al
c002599f:	19 c0                	sbb    %eax,%eax
c00259a1:	83 e0 f3             	and    $0xfffffff3,%eax
c00259a4:	83 c0 2d             	add    $0x2d,%eax
c00259a7:	89 44 24 24          	mov    %eax,0x24(%esp)
c00259ab:	eb 17                	jmp    c00259c4 <format_integer+0x60>
        sign = '-';
c00259ad:	3c 01                	cmp    $0x1,%al
c00259af:	19 c0                	sbb    %eax,%eax
c00259b1:	f7 d0                	not    %eax
c00259b3:	83 e0 2d             	and    $0x2d,%eax
c00259b6:	89 44 24 24          	mov    %eax,0x24(%esp)
c00259ba:	eb 08                	jmp    c00259c4 <format_integer+0x60>
  sign = 0;
c00259bc:	c7 44 24 24 00 00 00 	movl   $0x0,0x24(%esp)
c00259c3:	00 
  x = (c->flags & POUND) && value ? b->x : 0;
c00259c4:	8b 84 24 98 00 00 00 	mov    0x98(%esp),%eax
c00259cb:	8b 00                	mov    (%eax),%eax
c00259cd:	89 44 24 28          	mov    %eax,0x28(%esp)
c00259d1:	83 e0 08             	and    $0x8,%eax
c00259d4:	89 44 24 2c          	mov    %eax,0x2c(%esp)
c00259d8:	74 1a                	je     c00259f4 <format_integer+0x90>
c00259da:	89 fa                	mov    %edi,%edx
c00259dc:	09 f2                	or     %esi,%edx
c00259de:	0f 84 cc 00 00 00    	je     c0025ab0 <format_integer+0x14c>
c00259e4:	8b 84 24 94 00 00 00 	mov    0x94(%esp),%eax
c00259eb:	8b 40 08             	mov    0x8(%eax),%eax
c00259ee:	89 44 24 20          	mov    %eax,0x20(%esp)
c00259f2:	eb 12                	jmp    c0025a06 <format_integer+0xa2>
  while (value > 0) 
c00259f4:	89 fa                	mov    %edi,%edx
c00259f6:	09 f2                	or     %esi,%edx
c00259f8:	0f 84 c3 01 00 00    	je     c0025bc1 <format_integer+0x25d>
  x = (c->flags & POUND) && value ? b->x : 0;
c00259fe:	c7 44 24 20 00 00 00 	movl   $0x0,0x20(%esp)
c0025a05:	00 
      *cp++ = b->digits[value % b->base];
c0025a06:	8b 84 24 94 00 00 00 	mov    0x94(%esp),%eax
c0025a0d:	8b 40 04             	mov    0x4(%eax),%eax
c0025a10:	89 44 24 18          	mov    %eax,0x18(%esp)
c0025a14:	8b 84 24 94 00 00 00 	mov    0x94(%esp),%eax
c0025a1b:	8b 00                	mov    (%eax),%eax
c0025a1d:	89 44 24 08          	mov    %eax,0x8(%esp)
c0025a21:	89 c1                	mov    %eax,%ecx
c0025a23:	c1 f9 1f             	sar    $0x1f,%ecx
c0025a26:	89 4c 24 0c          	mov    %ecx,0xc(%esp)
c0025a2a:	c7 44 24 14 00 00 00 	movl   $0x0,0x14(%esp)
c0025a31:	00 
c0025a32:	8d 5c 24 30          	lea    0x30(%esp),%ebx
      if ((c->flags & GROUP) && digit_cnt > 0 && digit_cnt % b->group == 0)
c0025a36:	8b 44 24 28          	mov    0x28(%esp),%eax
c0025a3a:	83 e0 20             	and    $0x20,%eax
c0025a3d:	89 44 24 1c          	mov    %eax,0x1c(%esp)
c0025a41:	eb 3f                	jmp    c0025a82 <format_integer+0x11e>
c0025a43:	89 dd                	mov    %ebx,%ebp
      *cp++ = b->digits[value % b->base];
c0025a45:	8d 5d 01             	lea    0x1(%ebp),%ebx
c0025a48:	ff 74 24 0c          	pushl  0xc(%esp)
c0025a4c:	ff 74 24 0c          	pushl  0xc(%esp)
c0025a50:	57                   	push   %edi
c0025a51:	56                   	push   %esi
c0025a52:	e8 35 18 00 00       	call   c002728c <__umoddi3>
c0025a57:	83 c4 10             	add    $0x10,%esp
c0025a5a:	8b 4c 24 18          	mov    0x18(%esp),%ecx
c0025a5e:	8a 04 01             	mov    (%ecx,%eax,1),%al
c0025a61:	88 45 00             	mov    %al,0x0(%ebp)
      value /= b->base;
c0025a64:	ff 74 24 0c          	pushl  0xc(%esp)
c0025a68:	ff 74 24 0c          	pushl  0xc(%esp)
c0025a6c:	57                   	push   %edi
c0025a6d:	56                   	push   %esi
c0025a6e:	e8 fd 17 00 00       	call   c0027270 <__udivdi3>
c0025a73:	83 c4 10             	add    $0x10,%esp
c0025a76:	89 c6                	mov    %eax,%esi
c0025a78:	89 d7                	mov    %edx,%edi
      digit_cnt++;
c0025a7a:	ff 44 24 14          	incl   0x14(%esp)
  while (value > 0) 
c0025a7e:	09 c2                	or     %eax,%edx
c0025a80:	74 3a                	je     c0025abc <format_integer+0x158>
      if ((c->flags & GROUP) && digit_cnt > 0 && digit_cnt % b->group == 0)
c0025a82:	83 7c 24 1c 00       	cmpl   $0x0,0x1c(%esp)
c0025a87:	74 ba                	je     c0025a43 <format_integer+0xdf>
c0025a89:	8b 44 24 14          	mov    0x14(%esp),%eax
c0025a8d:	85 c0                	test   %eax,%eax
c0025a8f:	7e 17                	jle    c0025aa8 <format_integer+0x144>
c0025a91:	8b 8c 24 94 00 00 00 	mov    0x94(%esp),%ecx
c0025a98:	99                   	cltd   
c0025a99:	f7 79 0c             	idivl  0xc(%ecx)
c0025a9c:	85 d2                	test   %edx,%edx
c0025a9e:	75 0c                	jne    c0025aac <format_integer+0x148>
        *cp++ = ',';
c0025aa0:	8d 6b 01             	lea    0x1(%ebx),%ebp
c0025aa3:	c6 03 2c             	movb   $0x2c,(%ebx)
c0025aa6:	eb 9d                	jmp    c0025a45 <format_integer+0xe1>
c0025aa8:	89 dd                	mov    %ebx,%ebp
c0025aaa:	eb 99                	jmp    c0025a45 <format_integer+0xe1>
c0025aac:	89 dd                	mov    %ebx,%ebp
c0025aae:	eb 95                	jmp    c0025a45 <format_integer+0xe1>
  x = (c->flags & POUND) && value ? b->x : 0;
c0025ab0:	c7 44 24 20 00 00 00 	movl   $0x0,0x20(%esp)
c0025ab7:	00 
  cp = buf;
c0025ab8:	8d 5c 24 30          	lea    0x30(%esp),%ebx
  precision = c->precision < 0 ? 1 : c->precision;
c0025abc:	8b 84 24 98 00 00 00 	mov    0x98(%esp),%eax
c0025ac3:	8b 50 08             	mov    0x8(%eax),%edx
c0025ac6:	85 d2                	test   %edx,%edx
c0025ac8:	0f 88 04 01 00 00    	js     c0025bd2 <format_integer+0x26e>
  while (cp - buf < precision && cp < buf + sizeof buf - 1)
c0025ace:	8d 7c 24 30          	lea    0x30(%esp),%edi
c0025ad2:	89 d8                	mov    %ebx,%eax
c0025ad4:	29 f8                	sub    %edi,%eax
c0025ad6:	39 c2                	cmp    %eax,%edx
c0025ad8:	7e 21                	jle    c0025afb <format_integer+0x197>
c0025ada:	8d 44 24 6f          	lea    0x6f(%esp),%eax
c0025ade:	39 c3                	cmp    %eax,%ebx
c0025ae0:	73 19                	jae    c0025afb <format_integer+0x197>
c0025ae2:	89 f9                	mov    %edi,%ecx
c0025ae4:	89 c6                	mov    %eax,%esi
    *cp++ = '0';
c0025ae6:	43                   	inc    %ebx
c0025ae7:	c6 43 ff 30          	movb   $0x30,-0x1(%ebx)
  while (cp - buf < precision && cp < buf + sizeof buf - 1)
c0025aeb:	89 d8                	mov    %ebx,%eax
c0025aed:	29 c8                	sub    %ecx,%eax
c0025aef:	39 d0                	cmp    %edx,%eax
c0025af1:	7d 08                	jge    c0025afb <format_integer+0x197>
c0025af3:	39 f3                	cmp    %esi,%ebx
c0025af5:	75 ef                	jne    c0025ae6 <format_integer+0x182>
    *cp++ = '0';
c0025af7:	8d 5c 24 6f          	lea    0x6f(%esp),%ebx
  if ((c->flags & POUND) && b->base == 8 && (cp == buf || cp[-1] != '0'))
c0025afb:	83 7c 24 2c 00       	cmpl   $0x0,0x2c(%esp)
c0025b00:	74 10                	je     c0025b12 <format_integer+0x1ae>
c0025b02:	8b 84 24 94 00 00 00 	mov    0x94(%esp),%eax
c0025b09:	83 38 08             	cmpl   $0x8,(%eax)
c0025b0c:	0f 84 ca 00 00 00    	je     c0025bdc <format_integer+0x278>
  pad_cnt = c->width - (cp - buf) - (x ? 2 : 0) - (sign != 0);
c0025b12:	29 df                	sub    %ebx,%edi
c0025b14:	8b 8c 24 98 00 00 00 	mov    0x98(%esp),%ecx
c0025b1b:	89 f8                	mov    %edi,%eax
c0025b1d:	03 41 04             	add    0x4(%ecx),%eax
c0025b20:	83 7c 24 20 00       	cmpl   $0x0,0x20(%esp)
c0025b25:	0f 95 c2             	setne  %dl
c0025b28:	0f b6 d2             	movzbl %dl,%edx
c0025b2b:	d1 e2                	shl    %edx
c0025b2d:	29 d0                	sub    %edx,%eax
c0025b2f:	83 7c 24 24 00       	cmpl   $0x0,0x24(%esp)
c0025b34:	0f 95 c2             	setne  %dl
c0025b37:	0f b6 d2             	movzbl %dl,%edx
c0025b3a:	29 d0                	sub    %edx,%eax
c0025b3c:	89 c7                	mov    %eax,%edi
c0025b3e:	85 c0                	test   %eax,%eax
c0025b40:	0f 88 b3 00 00 00    	js     c0025bf9 <format_integer+0x295>
  if ((c->flags & (MINUS | ZERO)) == 0)
c0025b46:	f6 44 24 28 11       	testb  $0x11,0x28(%esp)
c0025b4b:	0f 84 b2 00 00 00    	je     c0025c03 <format_integer+0x29f>
  if (sign)
c0025b51:	83 7c 24 24 00       	cmpl   $0x0,0x24(%esp)
c0025b56:	0f 85 cc 00 00 00    	jne    c0025c28 <format_integer+0x2c4>
  if (x) 
c0025b5c:	83 7c 24 20 00       	cmpl   $0x0,0x20(%esp)
c0025b61:	0f 85 de 00 00 00    	jne    c0025c45 <format_integer+0x2e1>
  if (c->flags & ZERO)
c0025b67:	8b 84 24 98 00 00 00 	mov    0x98(%esp),%eax
c0025b6e:	f6 00 10             	testb  $0x10,(%eax)
c0025b71:	0f 85 00 01 00 00    	jne    c0025c77 <format_integer+0x313>
  while (cp > buf)
c0025b77:	8d 44 24 30          	lea    0x30(%esp),%eax
c0025b7b:	39 c3                	cmp    %eax,%ebx
c0025b7d:	76 2a                	jbe    c0025ba9 <format_integer+0x245>
c0025b7f:	89 c6                	mov    %eax,%esi
c0025b81:	89 7c 24 08          	mov    %edi,0x8(%esp)
c0025b85:	8b bc 24 9c 00 00 00 	mov    0x9c(%esp),%edi
c0025b8c:	8b ac 24 a0 00 00 00 	mov    0xa0(%esp),%ebp
    output (*--cp, aux);
c0025b93:	4b                   	dec    %ebx
c0025b94:	83 ec 08             	sub    $0x8,%esp
c0025b97:	55                   	push   %ebp
c0025b98:	0f be 03             	movsbl (%ebx),%eax
c0025b9b:	50                   	push   %eax
c0025b9c:	ff d7                	call   *%edi
  while (cp > buf)
c0025b9e:	83 c4 10             	add    $0x10,%esp
c0025ba1:	39 f3                	cmp    %esi,%ebx
c0025ba3:	75 ee                	jne    c0025b93 <format_integer+0x22f>
c0025ba5:	8b 7c 24 08          	mov    0x8(%esp),%edi
  if (c->flags & MINUS)
c0025ba9:	8b 84 24 98 00 00 00 	mov    0x98(%esp),%eax
c0025bb0:	f6 00 01             	testb  $0x1,(%eax)
c0025bb3:	0f 85 e3 00 00 00    	jne    c0025c9c <format_integer+0x338>
}
c0025bb9:	83 c4 7c             	add    $0x7c,%esp
c0025bbc:	5b                   	pop    %ebx
c0025bbd:	5e                   	pop    %esi
c0025bbe:	5f                   	pop    %edi
c0025bbf:	5d                   	pop    %ebp
c0025bc0:	c3                   	ret    
  x = (c->flags & POUND) && value ? b->x : 0;
c0025bc1:	c7 44 24 20 00 00 00 	movl   $0x0,0x20(%esp)
c0025bc8:	00 
  cp = buf;
c0025bc9:	8d 5c 24 30          	lea    0x30(%esp),%ebx
c0025bcd:	e9 ea fe ff ff       	jmp    c0025abc <format_integer+0x158>
  precision = c->precision < 0 ? 1 : c->precision;
c0025bd2:	ba 01 00 00 00       	mov    $0x1,%edx
c0025bd7:	e9 f2 fe ff ff       	jmp    c0025ace <format_integer+0x16a>
  if ((c->flags & POUND) && b->base == 8 && (cp == buf || cp[-1] != '0'))
c0025bdc:	8d 44 24 30          	lea    0x30(%esp),%eax
c0025be0:	39 c3                	cmp    %eax,%ebx
c0025be2:	74 0a                	je     c0025bee <format_integer+0x28a>
c0025be4:	80 7b ff 30          	cmpb   $0x30,-0x1(%ebx)
c0025be8:	0f 84 24 ff ff ff    	je     c0025b12 <format_integer+0x1ae>
    *cp++ = '0';
c0025bee:	c6 03 30             	movb   $0x30,(%ebx)
c0025bf1:	8d 5b 01             	lea    0x1(%ebx),%ebx
c0025bf4:	e9 19 ff ff ff       	jmp    c0025b12 <format_integer+0x1ae>
c0025bf9:	bf 00 00 00 00       	mov    $0x0,%edi
c0025bfe:	e9 43 ff ff ff       	jmp    c0025b46 <format_integer+0x1e2>
    output_dup (' ', pad_cnt, output, aux);
c0025c03:	83 ec 0c             	sub    $0xc,%esp
c0025c06:	ff b4 24 ac 00 00 00 	pushl  0xac(%esp)
c0025c0d:	8b 8c 24 ac 00 00 00 	mov    0xac(%esp),%ecx
c0025c14:	89 fa                	mov    %edi,%edx
c0025c16:	b8 20 00 00 00       	mov    $0x20,%eax
c0025c1b:	e8 15 fd ff ff       	call   c0025935 <output_dup>
c0025c20:	83 c4 10             	add    $0x10,%esp
c0025c23:	e9 29 ff ff ff       	jmp    c0025b51 <format_integer+0x1ed>
    output (sign, aux);
c0025c28:	83 ec 08             	sub    $0x8,%esp
c0025c2b:	ff b4 24 a8 00 00 00 	pushl  0xa8(%esp)
c0025c32:	ff 74 24 30          	pushl  0x30(%esp)
c0025c36:	ff 94 24 ac 00 00 00 	call   *0xac(%esp)
c0025c3d:	83 c4 10             	add    $0x10,%esp
c0025c40:	e9 17 ff ff ff       	jmp    c0025b5c <format_integer+0x1f8>
      output ('0', aux);
c0025c45:	83 ec 08             	sub    $0x8,%esp
c0025c48:	ff b4 24 a8 00 00 00 	pushl  0xa8(%esp)
c0025c4f:	6a 30                	push   $0x30
c0025c51:	ff 94 24 ac 00 00 00 	call   *0xac(%esp)
      output (x, aux); 
c0025c58:	83 c4 08             	add    $0x8,%esp
c0025c5b:	ff b4 24 a8 00 00 00 	pushl  0xa8(%esp)
c0025c62:	0f be 44 24 2c       	movsbl 0x2c(%esp),%eax
c0025c67:	50                   	push   %eax
c0025c68:	ff 94 24 ac 00 00 00 	call   *0xac(%esp)
c0025c6f:	83 c4 10             	add    $0x10,%esp
c0025c72:	e9 f0 fe ff ff       	jmp    c0025b67 <format_integer+0x203>
    output_dup ('0', pad_cnt, output, aux);
c0025c77:	83 ec 0c             	sub    $0xc,%esp
c0025c7a:	ff b4 24 ac 00 00 00 	pushl  0xac(%esp)
c0025c81:	8b 8c 24 ac 00 00 00 	mov    0xac(%esp),%ecx
c0025c88:	89 fa                	mov    %edi,%edx
c0025c8a:	b8 30 00 00 00       	mov    $0x30,%eax
c0025c8f:	e8 a1 fc ff ff       	call   c0025935 <output_dup>
c0025c94:	83 c4 10             	add    $0x10,%esp
c0025c97:	e9 db fe ff ff       	jmp    c0025b77 <format_integer+0x213>
    output_dup (' ', pad_cnt, output, aux);
c0025c9c:	83 ec 0c             	sub    $0xc,%esp
c0025c9f:	ff b4 24 ac 00 00 00 	pushl  0xac(%esp)
c0025ca6:	8b 8c 24 ac 00 00 00 	mov    0xac(%esp),%ecx
c0025cad:	89 fa                	mov    %edi,%edx
c0025caf:	b8 20 00 00 00       	mov    $0x20,%eax
c0025cb4:	e8 7c fc ff ff       	call   c0025935 <output_dup>
c0025cb9:	83 c4 10             	add    $0x10,%esp
}
c0025cbc:	e9 f8 fe ff ff       	jmp    c0025bb9 <format_integer+0x255>

c0025cc1 <format_string>:
   auxiliary data AUX. */
static void
format_string (const char *string, int length,
               struct printf_conversion *c,
               void (*output) (char, void *), void *aux) 
{
c0025cc1:	55                   	push   %ebp
c0025cc2:	57                   	push   %edi
c0025cc3:	56                   	push   %esi
c0025cc4:	53                   	push   %ebx
c0025cc5:	83 ec 1c             	sub    $0x1c,%esp
c0025cc8:	89 c5                	mov    %eax,%ebp
c0025cca:	89 d3                	mov    %edx,%ebx
c0025ccc:	89 54 24 08          	mov    %edx,0x8(%esp)
c0025cd0:	89 4c 24 0c          	mov    %ecx,0xc(%esp)
c0025cd4:	8b 74 24 30          	mov    0x30(%esp),%esi
c0025cd8:	8b 7c 24 34          	mov    0x34(%esp),%edi
  int i;
  if (c->width > length && (c->flags & MINUS) == 0)
c0025cdc:	8b 51 04             	mov    0x4(%ecx),%edx
c0025cdf:	39 da                	cmp    %ebx,%edx
c0025ce1:	7e 42                	jle    c0025d25 <format_string+0x64>
c0025ce3:	89 c8                	mov    %ecx,%eax
c0025ce5:	f6 00 01             	testb  $0x1,(%eax)
c0025ce8:	74 20                	je     c0025d0a <format_string+0x49>
    output_dup (' ', c->width - length, output, aux);
  for (i = 0; i < length; i++)
c0025cea:	83 7c 24 08 00       	cmpl   $0x0,0x8(%esp)
c0025cef:	7f 3b                	jg     c0025d2c <format_string+0x6b>
    output (string[i], aux);
  if (c->width > length && (c->flags & MINUS) != 0)
    output_dup (' ', c->width - length, output, aux);
c0025cf1:	2b 54 24 08          	sub    0x8(%esp),%edx
c0025cf5:	83 ec 0c             	sub    $0xc,%esp
c0025cf8:	57                   	push   %edi
c0025cf9:	89 f1                	mov    %esi,%ecx
c0025cfb:	b8 20 00 00 00       	mov    $0x20,%eax
c0025d00:	e8 30 fc ff ff       	call   c0025935 <output_dup>
c0025d05:	83 c4 10             	add    $0x10,%esp
}
c0025d08:	eb 4f                	jmp    c0025d59 <format_string+0x98>
    output_dup (' ', c->width - length, output, aux);
c0025d0a:	29 da                	sub    %ebx,%edx
c0025d0c:	83 ec 0c             	sub    $0xc,%esp
c0025d0f:	57                   	push   %edi
c0025d10:	89 f1                	mov    %esi,%ecx
c0025d12:	b8 20 00 00 00       	mov    $0x20,%eax
c0025d17:	e8 19 fc ff ff       	call   c0025935 <output_dup>
  for (i = 0; i < length; i++)
c0025d1c:	83 c4 10             	add    $0x10,%esp
c0025d1f:	85 db                	test   %ebx,%ebx
c0025d21:	7f 09                	jg     c0025d2c <format_string+0x6b>
c0025d23:	eb 22                	jmp    c0025d47 <format_string+0x86>
c0025d25:	83 7c 24 08 00       	cmpl   $0x0,0x8(%esp)
c0025d2a:	7e 2d                	jle    c0025d59 <format_string+0x98>
{
c0025d2c:	bb 00 00 00 00       	mov    $0x0,%ebx
    output (string[i], aux);
c0025d31:	83 ec 08             	sub    $0x8,%esp
c0025d34:	57                   	push   %edi
c0025d35:	0f be 44 1d 00       	movsbl 0x0(%ebp,%ebx,1),%eax
c0025d3a:	50                   	push   %eax
c0025d3b:	ff d6                	call   *%esi
  for (i = 0; i < length; i++)
c0025d3d:	43                   	inc    %ebx
c0025d3e:	83 c4 10             	add    $0x10,%esp
c0025d41:	39 5c 24 08          	cmp    %ebx,0x8(%esp)
c0025d45:	7f ea                	jg     c0025d31 <format_string+0x70>
  if (c->width > length && (c->flags & MINUS) != 0)
c0025d47:	8b 44 24 0c          	mov    0xc(%esp),%eax
c0025d4b:	8b 50 04             	mov    0x4(%eax),%edx
c0025d4e:	39 54 24 08          	cmp    %edx,0x8(%esp)
c0025d52:	7d 05                	jge    c0025d59 <format_string+0x98>
c0025d54:	f6 00 01             	testb  $0x1,(%eax)
c0025d57:	75 98                	jne    c0025cf1 <format_string+0x30>
}
c0025d59:	83 c4 1c             	add    $0x1c,%esp
c0025d5c:	5b                   	pop    %ebx
c0025d5d:	5e                   	pop    %esi
c0025d5e:	5f                   	pop    %edi
c0025d5f:	5d                   	pop    %ebp
c0025d60:	c3                   	ret    

c0025d61 <printf>:
{
c0025d61:	83 ec 0c             	sub    $0xc,%esp
  va_start (args, format);
c0025d64:	8d 44 24 14          	lea    0x14(%esp),%eax
  retval = vprintf (format, args);
c0025d68:	83 ec 08             	sub    $0x8,%esp
c0025d6b:	50                   	push   %eax
c0025d6c:	ff 74 24 1c          	pushl  0x1c(%esp)
c0025d70:	e8 b4 34 00 00       	call   c0029229 <vprintf>
}
c0025d75:	83 c4 1c             	add    $0x1c,%esp
c0025d78:	c3                   	ret    

c0025d79 <__printf>:
/* Wrapper for __vprintf() that converts varargs into a
   va_list. */
void
__printf (const char *format,
          void (*output) (char, void *), void *aux, ...) 
{
c0025d79:	83 ec 0c             	sub    $0xc,%esp
  va_list args;

  va_start (args, aux);
c0025d7c:	8d 44 24 1c          	lea    0x1c(%esp),%eax
  __vprintf (format, args, output, aux);
c0025d80:	ff 74 24 18          	pushl  0x18(%esp)
c0025d84:	ff 74 24 18          	pushl  0x18(%esp)
c0025d88:	50                   	push   %eax
c0025d89:	ff 74 24 1c          	pushl  0x1c(%esp)
c0025d8d:	e8 04 00 00 00       	call   c0025d96 <__vprintf>
  va_end (args);
}
c0025d92:	83 c4 1c             	add    $0x1c,%esp
c0025d95:	c3                   	ret    

c0025d96 <__vprintf>:
{
c0025d96:	55                   	push   %ebp
c0025d97:	57                   	push   %edi
c0025d98:	56                   	push   %esi
c0025d99:	53                   	push   %ebx
c0025d9a:	83 ec 3c             	sub    $0x3c,%esp
c0025d9d:	8b 74 24 50          	mov    0x50(%esp),%esi
  for (; *format != '\0'; format++)
c0025da1:	8a 06                	mov    (%esi),%al
c0025da3:	84 c0                	test   %al,%al
c0025da5:	75 44                	jne    c0025deb <__vprintf+0x55>
}
c0025da7:	83 c4 3c             	add    $0x3c,%esp
c0025daa:	5b                   	pop    %ebx
c0025dab:	5e                   	pop    %esi
c0025dac:	5f                   	pop    %edi
c0025dad:	5d                   	pop    %ebp
c0025dae:	c3                   	ret    
      format++;
c0025daf:	8d 5e 01             	lea    0x1(%esi),%ebx
      if (*format == '%') 
c0025db2:	80 7e 01 25          	cmpb   $0x25,0x1(%esi)
c0025db6:	74 19                	je     c0025dd1 <__vprintf+0x3b>
  c->flags = 0;
c0025db8:	c7 44 24 20 00 00 00 	movl   $0x0,0x20(%esp)
c0025dbf:	00 
c0025dc0:	bf 00 00 00 00       	mov    $0x0,%edi
c0025dc5:	be 00 00 00 00       	mov    $0x0,%esi
c0025dca:	bd 01 00 00 00       	mov    $0x1,%ebp
c0025dcf:	eb 3b                	jmp    c0025e0c <__vprintf+0x76>
          output ('%', aux);
c0025dd1:	83 ec 08             	sub    $0x8,%esp
c0025dd4:	ff 74 24 64          	pushl  0x64(%esp)
c0025dd8:	6a 25                	push   $0x25
c0025dda:	ff 54 24 68          	call   *0x68(%esp)
          continue;
c0025dde:	83 c4 10             	add    $0x10,%esp
  for (; *format != '\0'; format++)
c0025de1:	8d 73 01             	lea    0x1(%ebx),%esi
c0025de4:	8a 43 01             	mov    0x1(%ebx),%al
c0025de7:	84 c0                	test   %al,%al
c0025de9:	74 bc                	je     c0025da7 <__vprintf+0x11>
      if (*format != '%') 
c0025deb:	3c 25                	cmp    $0x25,%al
c0025ded:	74 c0                	je     c0025daf <__vprintf+0x19>
          output (*format, aux);
c0025def:	83 ec 08             	sub    $0x8,%esp
c0025df2:	ff 74 24 64          	pushl  0x64(%esp)
c0025df6:	0f be c0             	movsbl %al,%eax
c0025df9:	50                   	push   %eax
c0025dfa:	ff 54 24 68          	call   *0x68(%esp)
          continue;
c0025dfe:	83 c4 10             	add    $0x10,%esp
c0025e01:	89 f3                	mov    %esi,%ebx
c0025e03:	eb dc                	jmp    c0025de1 <__vprintf+0x4b>
          c->flags |= MINUS;
c0025e05:	83 ce 01             	or     $0x1,%esi
c0025e08:	89 ef                	mov    %ebp,%edi
      switch (*format++) 
c0025e0a:	89 cb                	mov    %ecx,%ebx
c0025e0c:	8d 4b 01             	lea    0x1(%ebx),%ecx
c0025e0f:	8a 41 ff             	mov    -0x1(%ecx),%al
c0025e12:	8d 50 e0             	lea    -0x20(%eax),%edx
c0025e15:	80 fa 10             	cmp    $0x10,%dl
c0025e18:	77 23                	ja     c0025e3d <__vprintf+0xa7>
c0025e1a:	0f b6 d2             	movzbl %dl,%edx
c0025e1d:	ff 24 95 d0 c0 02 c0 	jmp    *-0x3ffd3f30(,%edx,4)
          c->flags |= PLUS;
c0025e24:	83 ce 02             	or     $0x2,%esi
c0025e27:	eb df                	jmp    c0025e08 <__vprintf+0x72>
          c->flags |= SPACE;
c0025e29:	83 ce 04             	or     $0x4,%esi
c0025e2c:	eb da                	jmp    c0025e08 <__vprintf+0x72>
          c->flags |= POUND;
c0025e2e:	83 ce 08             	or     $0x8,%esi
c0025e31:	eb d5                	jmp    c0025e08 <__vprintf+0x72>
          c->flags |= ZERO;
c0025e33:	83 ce 10             	or     $0x10,%esi
c0025e36:	eb d0                	jmp    c0025e08 <__vprintf+0x72>
          c->flags |= GROUP;
c0025e38:	83 ce 20             	or     $0x20,%esi
c0025e3b:	eb cb                	jmp    c0025e08 <__vprintf+0x72>
c0025e3d:	89 fa                	mov    %edi,%edx
c0025e3f:	84 d2                	test   %dl,%dl
c0025e41:	0f 85 85 00 00 00    	jne    c0025ecc <__vprintf+0x136>
  if (c->flags & PLUS)
c0025e47:	8b 54 24 20          	mov    0x20(%esp),%edx
c0025e4b:	f6 c2 02             	test   $0x2,%dl
c0025e4e:	74 07                	je     c0025e57 <__vprintf+0xc1>
    c->flags &= ~SPACE;
c0025e50:	83 e2 fb             	and    $0xfffffffb,%edx
c0025e53:	89 54 24 20          	mov    %edx,0x20(%esp)
  c->width = 0;
c0025e57:	c7 44 24 24 00 00 00 	movl   $0x0,0x24(%esp)
c0025e5e:	00 
  if (*format == '*')
c0025e5f:	3c 2a                	cmp    $0x2a,%al
c0025e61:	0f 84 81 00 00 00    	je     c0025ee8 <__vprintf+0x152>
      for (; isdigit (*format); format++)
c0025e67:	0f be c0             	movsbl %al,%eax
static inline int isdigit (int c) { return c >= '0' && c <= '9'; }
c0025e6a:	8d 48 d0             	lea    -0x30(%eax),%ecx
c0025e6d:	ba 00 00 00 00       	mov    $0x0,%edx
c0025e72:	83 f9 09             	cmp    $0x9,%ecx
c0025e75:	77 21                	ja     c0025e98 <__vprintf+0x102>
        c->width = c->width * 10 + *format - '0';
c0025e77:	8d 14 92             	lea    (%edx,%edx,4),%edx
c0025e7a:	01 d2                	add    %edx,%edx
c0025e7c:	8d 54 10 d0          	lea    -0x30(%eax,%edx,1),%edx
      for (; isdigit (*format); format++)
c0025e80:	43                   	inc    %ebx
c0025e81:	0f be 03             	movsbl (%ebx),%eax
c0025e84:	8d 48 d0             	lea    -0x30(%eax),%ecx
c0025e87:	83 f9 09             	cmp    $0x9,%ecx
c0025e8a:	76 eb                	jbe    c0025e77 <__vprintf+0xe1>
c0025e8c:	89 54 24 24          	mov    %edx,0x24(%esp)
  if (c->width < 0) 
c0025e90:	8b 44 24 24          	mov    0x24(%esp),%eax
c0025e94:	85 c0                	test   %eax,%eax
c0025e96:	78 69                	js     c0025f01 <__vprintf+0x16b>
  c->precision = -1;
c0025e98:	c7 44 24 28 ff ff ff 	movl   $0xffffffff,0x28(%esp)
c0025e9f:	ff 
  if (*format == '.') 
c0025ea0:	80 3b 2e             	cmpb   $0x2e,(%ebx)
c0025ea3:	74 69                	je     c0025f0e <__vprintf+0x178>
  if (c->precision >= 0)
c0025ea5:	8b 54 24 28          	mov    0x28(%esp),%edx
  c->type = INT;
c0025ea9:	c7 44 24 2c 03 00 00 	movl   $0x3,0x2c(%esp)
c0025eb0:	00 
  switch (*format++) 
c0025eb1:	8d 7b 01             	lea    0x1(%ebx),%edi
c0025eb4:	8a 03                	mov    (%ebx),%al
c0025eb6:	8d 48 98             	lea    -0x68(%eax),%ecx
c0025eb9:	80 f9 12             	cmp    $0x12,%cl
c0025ebc:	0f 87 d5 01 00 00    	ja     c0026097 <__vprintf+0x301>
c0025ec2:	0f b6 c9             	movzbl %cl,%ecx
c0025ec5:	ff 24 8d 14 c1 02 c0 	jmp    *-0x3ffd3eec(,%ecx,4)
c0025ecc:	89 74 24 20          	mov    %esi,0x20(%esp)
  if (c->flags & MINUS)
c0025ed0:	f7 c6 01 00 00 00    	test   $0x1,%esi
c0025ed6:	0f 84 6b ff ff ff    	je     c0025e47 <__vprintf+0xb1>
    c->flags &= ~ZERO;
c0025edc:	83 e6 ef             	and    $0xffffffef,%esi
c0025edf:	89 74 24 20          	mov    %esi,0x20(%esp)
c0025ee3:	e9 5f ff ff ff       	jmp    c0025e47 <__vprintf+0xb1>
      c->width = va_arg (*args, int);
c0025ee8:	8b 44 24 54          	mov    0x54(%esp),%eax
c0025eec:	8b 00                	mov    (%eax),%eax
c0025eee:	89 44 24 24          	mov    %eax,0x24(%esp)
c0025ef2:	8b 44 24 54          	mov    0x54(%esp),%eax
c0025ef6:	8d 40 04             	lea    0x4(%eax),%eax
c0025ef9:	89 44 24 54          	mov    %eax,0x54(%esp)
      switch (*format++) 
c0025efd:	89 cb                	mov    %ecx,%ebx
c0025eff:	eb 8f                	jmp    c0025e90 <__vprintf+0xfa>
      c->width = -c->width;
c0025f01:	f7 d8                	neg    %eax
c0025f03:	89 44 24 24          	mov    %eax,0x24(%esp)
      c->flags |= MINUS;
c0025f07:	83 4c 24 20 01       	orl    $0x1,0x20(%esp)
c0025f0c:	eb 8a                	jmp    c0025e98 <__vprintf+0x102>
      format++;
c0025f0e:	8d 53 01             	lea    0x1(%ebx),%edx
      if (*format == '*') 
c0025f11:	8a 43 01             	mov    0x1(%ebx),%al
c0025f14:	3c 2a                	cmp    $0x2a,%al
c0025f16:	74 45                	je     c0025f5d <__vprintf+0x1c7>
          c->precision = 0;
c0025f18:	c7 44 24 28 00 00 00 	movl   $0x0,0x28(%esp)
c0025f1f:	00 
          for (; isdigit (*format); format++)
c0025f20:	0f be c0             	movsbl %al,%eax
c0025f23:	8d 48 d0             	lea    -0x30(%eax),%ecx
c0025f26:	83 f9 09             	cmp    $0x9,%ecx
c0025f29:	77 59                	ja     c0025f84 <__vprintf+0x1ee>
c0025f2b:	b9 00 00 00 00       	mov    $0x0,%ecx
            c->precision = c->precision * 10 + *format - '0';
c0025f30:	8d 0c 89             	lea    (%ecx,%ecx,4),%ecx
c0025f33:	01 c9                	add    %ecx,%ecx
c0025f35:	8d 4c 08 d0          	lea    -0x30(%eax,%ecx,1),%ecx
          for (; isdigit (*format); format++)
c0025f39:	42                   	inc    %edx
c0025f3a:	0f be 02             	movsbl (%edx),%eax
c0025f3d:	8d 58 d0             	lea    -0x30(%eax),%ebx
c0025f40:	83 fb 09             	cmp    $0x9,%ebx
c0025f43:	76 eb                	jbe    c0025f30 <__vprintf+0x19a>
c0025f45:	89 4c 24 28          	mov    %ecx,0x28(%esp)
c0025f49:	89 d3                	mov    %edx,%ebx
      if (c->precision < 0) 
c0025f4b:	8b 54 24 28          	mov    0x28(%esp),%edx
c0025f4f:	85 d2                	test   %edx,%edx
c0025f51:	78 24                	js     c0025f77 <__vprintf+0x1e1>
    c->flags &= ~ZERO;
c0025f53:	83 64 24 20 ef       	andl   $0xffffffef,0x20(%esp)
c0025f58:	e9 4c ff ff ff       	jmp    c0025ea9 <__vprintf+0x113>
          format++;
c0025f5d:	83 c3 02             	add    $0x2,%ebx
          c->precision = va_arg (*args, int);
c0025f60:	8b 44 24 54          	mov    0x54(%esp),%eax
c0025f64:	8b 00                	mov    (%eax),%eax
c0025f66:	89 44 24 28          	mov    %eax,0x28(%esp)
c0025f6a:	8b 44 24 54          	mov    0x54(%esp),%eax
c0025f6e:	8d 40 04             	lea    0x4(%eax),%eax
c0025f71:	89 44 24 54          	mov    %eax,0x54(%esp)
c0025f75:	eb d4                	jmp    c0025f4b <__vprintf+0x1b5>
        c->precision = -1;
c0025f77:	c7 44 24 28 ff ff ff 	movl   $0xffffffff,0x28(%esp)
c0025f7e:	ff 
c0025f7f:	e9 21 ff ff ff       	jmp    c0025ea5 <__vprintf+0x10f>
      format++;
c0025f84:	89 d3                	mov    %edx,%ebx
  if (c->precision >= 0)
c0025f86:	ba 00 00 00 00       	mov    $0x0,%edx
c0025f8b:	eb c6                	jmp    c0025f53 <__vprintf+0x1bd>
      if (*format == 'h') 
c0025f8d:	8a 43 01             	mov    0x1(%ebx),%al
c0025f90:	3c 68                	cmp    $0x68,%al
c0025f92:	74 21                	je     c0025fb5 <__vprintf+0x21f>
        c->type = SHORT;
c0025f94:	c7 44 24 2c 02 00 00 	movl   $0x2,0x2c(%esp)
c0025f9b:	00 
      switch (*format) 
c0025f9c:	0f be e8             	movsbl %al,%ebp
c0025f9f:	8d 58 bb             	lea    -0x45(%eax),%ebx
c0025fa2:	80 fb 33             	cmp    $0x33,%bl
c0025fa5:	0f 87 ba 04 00 00    	ja     c0026465 <__vprintf+0x6cf>
c0025fab:	0f b6 db             	movzbl %bl,%ebx
c0025fae:	ff 24 9d 60 c1 02 c0 	jmp    *-0x3ffd3ea0(,%ebx,4)
          format++;
c0025fb5:	8d 7b 02             	lea    0x2(%ebx),%edi
          c->type = CHAR;
c0025fb8:	c7 44 24 2c 01 00 00 	movl   $0x1,0x2c(%esp)
c0025fbf:	00 
      switch (*format) 
c0025fc0:	8a 43 02             	mov    0x2(%ebx),%al
c0025fc3:	0f be e8             	movsbl %al,%ebp
c0025fc6:	8d 58 bb             	lea    -0x45(%eax),%ebx
c0025fc9:	80 fb 33             	cmp    $0x33,%bl
c0025fcc:	0f 87 93 04 00 00    	ja     c0026465 <__vprintf+0x6cf>
c0025fd2:	0f b6 db             	movzbl %bl,%ebx
c0025fd5:	ff 24 9d 30 c2 02 c0 	jmp    *-0x3ffd3dd0(,%ebx,4)
      c->type = INTMAX;
c0025fdc:	c7 44 24 2c 04 00 00 	movl   $0x4,0x2c(%esp)
c0025fe3:	00 
      switch (*format) 
c0025fe4:	8a 43 01             	mov    0x1(%ebx),%al
c0025fe7:	0f be e8             	movsbl %al,%ebp
c0025fea:	8d 58 bb             	lea    -0x45(%eax),%ebx
c0025fed:	80 fb 33             	cmp    $0x33,%bl
c0025ff0:	0f 87 6f 04 00 00    	ja     c0026465 <__vprintf+0x6cf>
c0025ff6:	0f b6 db             	movzbl %bl,%ebx
c0025ff9:	ff 24 9d 00 c3 02 c0 	jmp    *-0x3ffd3d00(,%ebx,4)
      if (*format == 'l')
c0026000:	8a 43 01             	mov    0x1(%ebx),%al
c0026003:	3c 6c                	cmp    $0x6c,%al
c0026005:	74 21                	je     c0026028 <__vprintf+0x292>
        c->type = LONG;
c0026007:	c7 44 24 2c 05 00 00 	movl   $0x5,0x2c(%esp)
c002600e:	00 
      switch (*format) 
c002600f:	0f be e8             	movsbl %al,%ebp
c0026012:	8d 58 bb             	lea    -0x45(%eax),%ebx
c0026015:	80 fb 33             	cmp    $0x33,%bl
c0026018:	0f 87 47 04 00 00    	ja     c0026465 <__vprintf+0x6cf>
c002601e:	0f b6 db             	movzbl %bl,%ebx
c0026021:	ff 24 9d d0 c3 02 c0 	jmp    *-0x3ffd3c30(,%ebx,4)
          format++;
c0026028:	8d 7b 02             	lea    0x2(%ebx),%edi
          c->type = LONGLONG;
c002602b:	c7 44 24 2c 06 00 00 	movl   $0x6,0x2c(%esp)
c0026032:	00 
      switch (*format) 
c0026033:	8a 43 02             	mov    0x2(%ebx),%al
c0026036:	0f be e8             	movsbl %al,%ebp
c0026039:	8d 58 bb             	lea    -0x45(%eax),%ebx
c002603c:	80 fb 33             	cmp    $0x33,%bl
c002603f:	0f 87 20 04 00 00    	ja     c0026465 <__vprintf+0x6cf>
c0026045:	0f b6 db             	movzbl %bl,%ebx
c0026048:	ff 24 9d a0 c4 02 c0 	jmp    *-0x3ffd3b60(,%ebx,4)
      c->type = PTRDIFFT;
c002604f:	c7 44 24 2c 07 00 00 	movl   $0x7,0x2c(%esp)
c0026056:	00 
      switch (*format) 
c0026057:	8a 43 01             	mov    0x1(%ebx),%al
c002605a:	0f be e8             	movsbl %al,%ebp
c002605d:	8d 58 bb             	lea    -0x45(%eax),%ebx
c0026060:	80 fb 33             	cmp    $0x33,%bl
c0026063:	0f 87 fc 03 00 00    	ja     c0026465 <__vprintf+0x6cf>
c0026069:	0f b6 db             	movzbl %bl,%ebx
c002606c:	ff 24 9d 70 c5 02 c0 	jmp    *-0x3ffd3a90(,%ebx,4)
      c->type = SIZET;
c0026073:	c7 44 24 2c 08 00 00 	movl   $0x8,0x2c(%esp)
c002607a:	00 
      switch (*format) 
c002607b:	8a 43 01             	mov    0x1(%ebx),%al
c002607e:	0f be e8             	movsbl %al,%ebp
c0026081:	8d 58 bb             	lea    -0x45(%eax),%ebx
c0026084:	80 fb 33             	cmp    $0x33,%bl
c0026087:	0f 87 d8 03 00 00    	ja     c0026465 <__vprintf+0x6cf>
c002608d:	0f b6 db             	movzbl %bl,%ebx
c0026090:	ff 24 9d 40 c6 02 c0 	jmp    *-0x3ffd39c0(,%ebx,4)
c0026097:	0f be e8             	movsbl %al,%ebp
c002609a:	8d 70 bb             	lea    -0x45(%eax),%esi
c002609d:	89 f1                	mov    %esi,%ecx
c002609f:	80 f9 33             	cmp    $0x33,%cl
c00260a2:	0f 87 bb 03 00 00    	ja     c0026463 <__vprintf+0x6cd>
c00260a8:	0f b6 f1             	movzbl %cl,%esi
c00260ab:	ff 24 b5 10 c7 02 c0 	jmp    *-0x3ffd38f0(,%esi,4)
c00260b2:	89 df                	mov    %ebx,%edi
            switch (c.type) 
c00260b4:	83 7c 24 2c 08       	cmpl   $0x8,0x2c(%esp)
c00260b9:	0f 87 fb 00 00 00    	ja     c00261ba <__vprintf+0x424>
c00260bf:	8b 44 24 2c          	mov    0x2c(%esp),%eax
c00260c3:	ff 24 85 e0 c7 02 c0 	jmp    *-0x3ffd3820(,%eax,4)
                value = (signed char) va_arg (args, int);
c00260ca:	8b 44 24 54          	mov    0x54(%esp),%eax
c00260ce:	0f be 08             	movsbl (%eax),%ecx
c00260d1:	89 cb                	mov    %ecx,%ebx
c00260d3:	c1 fb 1f             	sar    $0x1f,%ebx
c00260d6:	8d 40 04             	lea    0x4(%eax),%eax
c00260d9:	89 44 24 54          	mov    %eax,0x54(%esp)
            format_integer (value < 0 ? -value : value,
c00260dd:	89 c8                	mov    %ecx,%eax
c00260df:	89 da                	mov    %ebx,%edx
c00260e1:	85 db                	test   %ebx,%ebx
c00260e3:	0f 88 f3 00 00 00    	js     c00261dc <__vprintf+0x446>
c00260e9:	83 ec 0c             	sub    $0xc,%esp
c00260ec:	ff 74 24 68          	pushl  0x68(%esp)
c00260f0:	ff 74 24 68          	pushl  0x68(%esp)
c00260f4:	8d 74 24 34          	lea    0x34(%esp),%esi
c00260f8:	56                   	push   %esi
c00260f9:	68 40 c8 02 c0       	push   $0xc002c840
c00260fe:	89 d9                	mov    %ebx,%ecx
c0026100:	c1 e9 1f             	shr    $0x1f,%ecx
c0026103:	51                   	push   %ecx
c0026104:	b9 01 00 00 00       	mov    $0x1,%ecx
c0026109:	e8 56 f8 ff ff       	call   c0025964 <format_integer>
          break;
c002610e:	83 c4 20             	add    $0x20,%esp
c0026111:	89 fb                	mov    %edi,%ebx
c0026113:	e9 c9 fc ff ff       	jmp    c0025de1 <__vprintf+0x4b>
                value = (short) va_arg (args, int);
c0026118:	8b 44 24 54          	mov    0x54(%esp),%eax
c002611c:	0f bf 08             	movswl (%eax),%ecx
c002611f:	89 cb                	mov    %ecx,%ebx
c0026121:	c1 fb 1f             	sar    $0x1f,%ebx
c0026124:	8d 40 04             	lea    0x4(%eax),%eax
c0026127:	89 44 24 54          	mov    %eax,0x54(%esp)
                break;
c002612b:	eb b0                	jmp    c00260dd <__vprintf+0x347>
                value = va_arg (args, int);
c002612d:	8b 44 24 54          	mov    0x54(%esp),%eax
c0026131:	8b 08                	mov    (%eax),%ecx
c0026133:	89 cb                	mov    %ecx,%ebx
c0026135:	c1 fb 1f             	sar    $0x1f,%ebx
c0026138:	8d 40 04             	lea    0x4(%eax),%eax
c002613b:	89 44 24 54          	mov    %eax,0x54(%esp)
                break;
c002613f:	eb 9c                	jmp    c00260dd <__vprintf+0x347>
                value = va_arg (args, intmax_t);
c0026141:	8b 44 24 54          	mov    0x54(%esp),%eax
c0026145:	8b 08                	mov    (%eax),%ecx
c0026147:	8b 58 04             	mov    0x4(%eax),%ebx
c002614a:	8d 40 08             	lea    0x8(%eax),%eax
c002614d:	89 44 24 54          	mov    %eax,0x54(%esp)
                break;
c0026151:	eb 8a                	jmp    c00260dd <__vprintf+0x347>
                value = va_arg (args, long);
c0026153:	8b 44 24 54          	mov    0x54(%esp),%eax
c0026157:	8b 08                	mov    (%eax),%ecx
c0026159:	89 cb                	mov    %ecx,%ebx
c002615b:	c1 fb 1f             	sar    $0x1f,%ebx
c002615e:	8d 40 04             	lea    0x4(%eax),%eax
c0026161:	89 44 24 54          	mov    %eax,0x54(%esp)
                break;
c0026165:	e9 73 ff ff ff       	jmp    c00260dd <__vprintf+0x347>
                value = va_arg (args, long long);
c002616a:	8b 44 24 54          	mov    0x54(%esp),%eax
c002616e:	8b 08                	mov    (%eax),%ecx
c0026170:	8b 58 04             	mov    0x4(%eax),%ebx
c0026173:	8d 40 08             	lea    0x8(%eax),%eax
c0026176:	89 44 24 54          	mov    %eax,0x54(%esp)
                break;
c002617a:	e9 5e ff ff ff       	jmp    c00260dd <__vprintf+0x347>
                value = va_arg (args, ptrdiff_t);
c002617f:	8b 44 24 54          	mov    0x54(%esp),%eax
c0026183:	8b 08                	mov    (%eax),%ecx
c0026185:	89 cb                	mov    %ecx,%ebx
c0026187:	c1 fb 1f             	sar    $0x1f,%ebx
c002618a:	8d 40 04             	lea    0x4(%eax),%eax
c002618d:	89 44 24 54          	mov    %eax,0x54(%esp)
                break;
c0026191:	e9 47 ff ff ff       	jmp    c00260dd <__vprintf+0x347>
                value = va_arg (args, size_t);
c0026196:	8b 44 24 54          	mov    0x54(%esp),%eax
c002619a:	83 c0 04             	add    $0x4,%eax
c002619d:	8b 74 24 54          	mov    0x54(%esp),%esi
c00261a1:	8b 0e                	mov    (%esi),%ecx
c00261a3:	bb 00 00 00 00       	mov    $0x0,%ebx
                if (value > SIZE_MAX / 2)
c00261a8:	81 f9 ff ff ff 7f    	cmp    $0x7fffffff,%ecx
c00261ae:	76 23                	jbe    c00261d3 <__vprintf+0x43d>
                  value = value - SIZE_MAX - 1;
c00261b0:	4b                   	dec    %ebx
                value = va_arg (args, size_t);
c00261b1:	89 44 24 54          	mov    %eax,0x54(%esp)
c00261b5:	e9 23 ff ff ff       	jmp    c00260dd <__vprintf+0x347>
                NOT_REACHED ();
c00261ba:	68 4c d2 02 c0       	push   $0xc002d24c
c00261bf:	68 04 c8 02 c0       	push   $0xc002c804
c00261c4:	68 dc 00 00 00       	push   $0xdc
c00261c9:	68 9d e4 02 c0       	push   $0xc002e49d
c00261ce:	e8 3c 16 00 00       	call   c002780f <debug_panic>
                value = va_arg (args, size_t);
c00261d3:	89 44 24 54          	mov    %eax,0x54(%esp)
c00261d7:	e9 01 ff ff ff       	jmp    c00260dd <__vprintf+0x347>
            format_integer (value < 0 ? -value : value,
c00261dc:	f7 d8                	neg    %eax
c00261de:	83 d2 00             	adc    $0x0,%edx
c00261e1:	f7 da                	neg    %edx
c00261e3:	e9 01 ff ff ff       	jmp    c00260e9 <__vprintf+0x353>
                value = va_arg (args, unsigned);
c00261e8:	8b 7c 24 54          	mov    0x54(%esp),%edi
c00261ec:	8b 3f                	mov    (%edi),%edi
c00261ee:	bd 00 00 00 00       	mov    $0x0,%ebp
c00261f3:	89 7c 24 08          	mov    %edi,0x8(%esp)
c00261f7:	89 6c 24 0c          	mov    %ebp,0xc(%esp)
c00261fb:	8b 7c 24 54          	mov    0x54(%esp),%edi
c00261ff:	8d 7f 04             	lea    0x4(%edi),%edi
c0026202:	89 7c 24 54          	mov    %edi,0x54(%esp)
            switch (*format) 
c0026206:	3c 6f                	cmp    $0x6f,%al
c0026208:	0f 84 68 01 00 00    	je     c0026376 <__vprintf+0x5e0>
c002620e:	3c 6f                	cmp    $0x6f,%al
c0026210:	0f 8e 0a 01 00 00    	jle    c0026320 <__vprintf+0x58a>
c0026216:	3c 75                	cmp    $0x75,%al
c0026218:	0f 84 0d 01 00 00    	je     c002632b <__vprintf+0x595>
c002621e:	3c 78                	cmp    $0x78,%al
c0026220:	0f 85 37 01 00 00    	jne    c002635d <__vprintf+0x5c7>
              case 'x': b = &base_x; break;
c0026226:	b8 20 c8 02 c0       	mov    $0xc002c820,%eax
c002622b:	e9 00 01 00 00       	jmp    c0026330 <__vprintf+0x59a>
                value = (unsigned char) va_arg (args, unsigned);
c0026230:	8b 74 24 54          	mov    0x54(%esp),%esi
c0026234:	0f b6 16             	movzbl (%esi),%edx
c0026237:	89 54 24 08          	mov    %edx,0x8(%esp)
c002623b:	c7 44 24 0c 00 00 00 	movl   $0x0,0xc(%esp)
c0026242:	00 
                break;
c0026243:	89 fb                	mov    %edi,%ebx
                value = (unsigned char) va_arg (args, unsigned);
c0026245:	8d 7e 04             	lea    0x4(%esi),%edi
c0026248:	89 7c 24 54          	mov    %edi,0x54(%esp)
                break;
c002624c:	eb b8                	jmp    c0026206 <__vprintf+0x470>
                value = (unsigned short) va_arg (args, unsigned);
c002624e:	8b 74 24 54          	mov    0x54(%esp),%esi
c0026252:	0f b7 16             	movzwl (%esi),%edx
c0026255:	89 54 24 08          	mov    %edx,0x8(%esp)
c0026259:	c7 44 24 0c 00 00 00 	movl   $0x0,0xc(%esp)
c0026260:	00 
                break;
c0026261:	89 fb                	mov    %edi,%ebx
                value = (unsigned short) va_arg (args, unsigned);
c0026263:	8d 7e 04             	lea    0x4(%esi),%edi
c0026266:	89 7c 24 54          	mov    %edi,0x54(%esp)
                break;
c002626a:	eb 9a                	jmp    c0026206 <__vprintf+0x470>
                value = va_arg (args, uintmax_t);
c002626c:	8b 74 24 54          	mov    0x54(%esp),%esi
c0026270:	8b 1e                	mov    (%esi),%ebx
c0026272:	8b 76 04             	mov    0x4(%esi),%esi
c0026275:	89 5c 24 08          	mov    %ebx,0x8(%esp)
c0026279:	89 74 24 0c          	mov    %esi,0xc(%esp)
                break;
c002627d:	89 fb                	mov    %edi,%ebx
                value = va_arg (args, uintmax_t);
c002627f:	8b 7c 24 54          	mov    0x54(%esp),%edi
c0026283:	8d 7f 08             	lea    0x8(%edi),%edi
c0026286:	89 7c 24 54          	mov    %edi,0x54(%esp)
                break;
c002628a:	e9 77 ff ff ff       	jmp    c0026206 <__vprintf+0x470>
                value = va_arg (args, unsigned long);
c002628f:	8b 74 24 54          	mov    0x54(%esp),%esi
c0026293:	8b 1e                	mov    (%esi),%ebx
c0026295:	be 00 00 00 00       	mov    $0x0,%esi
c002629a:	89 5c 24 08          	mov    %ebx,0x8(%esp)
c002629e:	89 74 24 0c          	mov    %esi,0xc(%esp)
                break;
c00262a2:	89 fb                	mov    %edi,%ebx
                value = va_arg (args, unsigned long);
c00262a4:	8b 7c 24 54          	mov    0x54(%esp),%edi
c00262a8:	8d 7f 04             	lea    0x4(%edi),%edi
c00262ab:	89 7c 24 54          	mov    %edi,0x54(%esp)
                break;
c00262af:	e9 52 ff ff ff       	jmp    c0026206 <__vprintf+0x470>
                value = va_arg (args, unsigned long long);
c00262b4:	8b 74 24 54          	mov    0x54(%esp),%esi
c00262b8:	8b 1e                	mov    (%esi),%ebx
c00262ba:	8b 76 04             	mov    0x4(%esi),%esi
c00262bd:	89 5c 24 08          	mov    %ebx,0x8(%esp)
c00262c1:	89 74 24 0c          	mov    %esi,0xc(%esp)
                break;
c00262c5:	89 fb                	mov    %edi,%ebx
                value = va_arg (args, unsigned long long);
c00262c7:	8b 7c 24 54          	mov    0x54(%esp),%edi
c00262cb:	8d 7f 08             	lea    0x8(%edi),%edi
c00262ce:	89 7c 24 54          	mov    %edi,0x54(%esp)
                break;
c00262d2:	e9 2f ff ff ff       	jmp    c0026206 <__vprintf+0x470>
                value &= ((uintmax_t) PTRDIFF_MAX << 1) | 1;
c00262d7:	8b 74 24 54          	mov    0x54(%esp),%esi
c00262db:	8b 36                	mov    (%esi),%esi
c00262dd:	89 74 24 08          	mov    %esi,0x8(%esp)
c00262e1:	c7 44 24 0c 00 00 00 	movl   $0x0,0xc(%esp)
c00262e8:	00 
                break;
c00262e9:	89 fb                	mov    %edi,%ebx
                value = va_arg (args, ptrdiff_t);
c00262eb:	8b 7c 24 54          	mov    0x54(%esp),%edi
c00262ef:	8d 7f 04             	lea    0x4(%edi),%edi
c00262f2:	89 7c 24 54          	mov    %edi,0x54(%esp)
                break;
c00262f6:	e9 0b ff ff ff       	jmp    c0026206 <__vprintf+0x470>
                value = va_arg (args, size_t);
c00262fb:	8b 74 24 54          	mov    0x54(%esp),%esi
c00262ff:	8b 1e                	mov    (%esi),%ebx
c0026301:	be 00 00 00 00       	mov    $0x0,%esi
c0026306:	89 5c 24 08          	mov    %ebx,0x8(%esp)
c002630a:	89 74 24 0c          	mov    %esi,0xc(%esp)
                break;
c002630e:	89 fb                	mov    %edi,%ebx
                value = va_arg (args, size_t);
c0026310:	8b 7c 24 54          	mov    0x54(%esp),%edi
c0026314:	8d 7f 04             	lea    0x4(%edi),%edi
c0026317:	89 7c 24 54          	mov    %edi,0x54(%esp)
                break;
c002631b:	e9 e6 fe ff ff       	jmp    c0026206 <__vprintf+0x470>
            switch (*format) 
c0026320:	3c 58                	cmp    $0x58,%al
c0026322:	75 39                	jne    c002635d <__vprintf+0x5c7>
              case 'X': b = &base_X; break;
c0026324:	b8 10 c8 02 c0       	mov    $0xc002c810,%eax
c0026329:	eb 05                	jmp    c0026330 <__vprintf+0x59a>
              case 'u': b = &base_d; break;
c002632b:	b8 40 c8 02 c0       	mov    $0xc002c840,%eax
            format_integer (value, false, false, b, &c, output, aux);
c0026330:	83 ec 0c             	sub    $0xc,%esp
c0026333:	ff 74 24 68          	pushl  0x68(%esp)
c0026337:	ff 74 24 68          	pushl  0x68(%esp)
c002633b:	8d 7c 24 34          	lea    0x34(%esp),%edi
c002633f:	57                   	push   %edi
c0026340:	50                   	push   %eax
c0026341:	6a 00                	push   $0x0
c0026343:	b9 00 00 00 00       	mov    $0x0,%ecx
c0026348:	8b 44 24 28          	mov    0x28(%esp),%eax
c002634c:	8b 54 24 2c          	mov    0x2c(%esp),%edx
c0026350:	e8 0f f6 ff ff       	call   c0025964 <format_integer>
          break;
c0026355:	83 c4 20             	add    $0x20,%esp
c0026358:	e9 84 fa ff ff       	jmp    c0025de1 <__vprintf+0x4b>
              default: NOT_REACHED ();
c002635d:	68 4c d2 02 c0       	push   $0xc002d24c
c0026362:	68 04 c8 02 c0       	push   $0xc002c804
c0026367:	68 14 01 00 00       	push   $0x114
c002636c:	68 9d e4 02 c0       	push   $0xc002e49d
c0026371:	e8 99 14 00 00       	call   c002780f <debug_panic>
              case 'o': b = &base_o; break;
c0026376:	b8 30 c8 02 c0       	mov    $0xc002c830,%eax
c002637b:	eb b3                	jmp    c0026330 <__vprintf+0x59a>
      switch (*format) 
c002637d:	89 df                	mov    %ebx,%edi
            char ch = va_arg (args, int);
c002637f:	8b 44 24 54          	mov    0x54(%esp),%eax
c0026383:	8d 70 04             	lea    0x4(%eax),%esi
c0026386:	8b 00                	mov    (%eax),%eax
c0026388:	88 44 24 1f          	mov    %al,0x1f(%esp)
            format_string (&ch, 1, &c, output, aux);
c002638c:	83 ec 08             	sub    $0x8,%esp
c002638f:	ff 74 24 64          	pushl  0x64(%esp)
c0026393:	ff 74 24 64          	pushl  0x64(%esp)
c0026397:	8d 4c 24 30          	lea    0x30(%esp),%ecx
c002639b:	ba 01 00 00 00       	mov    $0x1,%edx
c00263a0:	8d 44 24 2f          	lea    0x2f(%esp),%eax
c00263a4:	e8 18 f9 ff ff       	call   c0025cc1 <format_string>
          break;
c00263a9:	83 c4 10             	add    $0x10,%esp
c00263ac:	89 fb                	mov    %edi,%ebx
            char ch = va_arg (args, int);
c00263ae:	89 74 24 54          	mov    %esi,0x54(%esp)
          break;
c00263b2:	e9 2a fa ff ff       	jmp    c0025de1 <__vprintf+0x4b>
      switch (*format) 
c00263b7:	89 df                	mov    %ebx,%edi
            const char *s = va_arg (args, char *);
c00263b9:	8b 44 24 54          	mov    0x54(%esp),%eax
c00263bd:	8d 70 04             	lea    0x4(%eax),%esi
c00263c0:	8b 18                	mov    (%eax),%ebx
            if (s == NULL)
c00263c2:	85 db                	test   %ebx,%ebx
c00263c4:	74 30                	je     c00263f6 <__vprintf+0x660>
            format_string (s, strnlen (s, c.precision), &c, output, aux);
c00263c6:	83 ec 08             	sub    $0x8,%esp
c00263c9:	52                   	push   %edx
c00263ca:	53                   	push   %ebx
c00263cb:	e8 0e 0b 00 00       	call   c0026ede <strnlen>
c00263d0:	83 c4 08             	add    $0x8,%esp
c00263d3:	ff 74 24 64          	pushl  0x64(%esp)
c00263d7:	ff 74 24 64          	pushl  0x64(%esp)
c00263db:	8d 4c 24 30          	lea    0x30(%esp),%ecx
c00263df:	89 c2                	mov    %eax,%edx
c00263e1:	89 d8                	mov    %ebx,%eax
c00263e3:	e8 d9 f8 ff ff       	call   c0025cc1 <format_string>
          break;
c00263e8:	83 c4 10             	add    $0x10,%esp
c00263eb:	89 fb                	mov    %edi,%ebx
            const char *s = va_arg (args, char *);
c00263ed:	89 74 24 54          	mov    %esi,0x54(%esp)
          break;
c00263f1:	e9 eb f9 ff ff       	jmp    c0025de1 <__vprintf+0x4b>
              s = "(null)";
c00263f6:	bb 96 e4 02 c0       	mov    $0xc002e496,%ebx
c00263fb:	eb c9                	jmp    c00263c6 <__vprintf+0x630>
      switch (*format) 
c00263fd:	89 df                	mov    %ebx,%edi
            void *p = va_arg (args, void *);
c00263ff:	8b 44 24 54          	mov    0x54(%esp),%eax
c0026403:	8d 70 04             	lea    0x4(%eax),%esi
c0026406:	8b 00                	mov    (%eax),%eax
            c.flags = POUND;
c0026408:	c7 44 24 20 08 00 00 	movl   $0x8,0x20(%esp)
c002640f:	00 
            format_integer ((uintptr_t) p, false, false,
c0026410:	83 ec 0c             	sub    $0xc,%esp
c0026413:	ff 74 24 68          	pushl  0x68(%esp)
c0026417:	ff 74 24 68          	pushl  0x68(%esp)
c002641b:	8d 5c 24 34          	lea    0x34(%esp),%ebx
c002641f:	53                   	push   %ebx
c0026420:	68 20 c8 02 c0       	push   $0xc002c820
c0026425:	6a 00                	push   $0x0
c0026427:	b9 00 00 00 00       	mov    $0x0,%ecx
c002642c:	ba 00 00 00 00       	mov    $0x0,%edx
c0026431:	e8 2e f5 ff ff       	call   c0025964 <format_integer>
          break;
c0026436:	83 c4 20             	add    $0x20,%esp
c0026439:	89 fb                	mov    %edi,%ebx
            void *p = va_arg (args, void *);
c002643b:	89 74 24 54          	mov    %esi,0x54(%esp)
          break;
c002643f:	e9 9d f9 ff ff       	jmp    c0025de1 <__vprintf+0x4b>
      switch (*format) 
c0026444:	89 df                	mov    %ebx,%edi
          __printf ("<<no %%%c in kernel>>", output, aux, *format);
c0026446:	55                   	push   %ebp
c0026447:	ff 74 24 60          	pushl  0x60(%esp)
c002644b:	ff 74 24 60          	pushl  0x60(%esp)
c002644f:	68 af e4 02 c0       	push   $0xc002e4af
c0026454:	e8 20 f9 ff ff       	call   c0025d79 <__printf>
          break;
c0026459:	83 c4 10             	add    $0x10,%esp
c002645c:	89 fb                	mov    %edi,%ebx
c002645e:	e9 7e f9 ff ff       	jmp    c0025de1 <__vprintf+0x4b>
      switch (*format) 
c0026463:	89 df                	mov    %ebx,%edi
          __printf ("<<no %%%c conversion>>", output, aux, *format);
c0026465:	55                   	push   %ebp
c0026466:	ff 74 24 60          	pushl  0x60(%esp)
c002646a:	ff 74 24 60          	pushl  0x60(%esp)
c002646e:	68 c5 e4 02 c0       	push   $0xc002e4c5
c0026473:	e8 01 f9 ff ff       	call   c0025d79 <__printf>
          break;
c0026478:	83 c4 10             	add    $0x10,%esp
c002647b:	89 fb                	mov    %edi,%ebx
c002647d:	e9 5f f9 ff ff       	jmp    c0025de1 <__vprintf+0x4b>

c0026482 <vsnprintf>:
{
c0026482:	53                   	push   %ebx
c0026483:	83 ec 18             	sub    $0x18,%esp
c0026486:	8b 44 24 24          	mov    0x24(%esp),%eax
c002648a:	8b 54 24 28          	mov    0x28(%esp),%edx
c002648e:	8b 4c 24 2c          	mov    0x2c(%esp),%ecx
  aux.p = buffer;
c0026492:	8b 5c 24 20          	mov    0x20(%esp),%ebx
c0026496:	89 5c 24 04          	mov    %ebx,0x4(%esp)
  aux.length = 0;
c002649a:	c7 44 24 08 00 00 00 	movl   $0x0,0x8(%esp)
c00264a1:	00 
  aux.max_length = buf_size > 0 ? buf_size - 1 : 0;
c00264a2:	85 c0                	test   %eax,%eax
c00264a4:	74 29                	je     c00264cf <vsnprintf+0x4d>
c00264a6:	48                   	dec    %eax
c00264a7:	89 44 24 0c          	mov    %eax,0xc(%esp)
  __vprintf (format, args, vsnprintf_helper, &aux);
c00264ab:	8d 44 24 04          	lea    0x4(%esp),%eax
c00264af:	50                   	push   %eax
c00264b0:	68 13 59 02 c0       	push   $0xc0025913
c00264b5:	51                   	push   %ecx
c00264b6:	52                   	push   %edx
c00264b7:	e8 da f8 ff ff       	call   c0025d96 <__vprintf>
    *aux.p = '\0';
c00264bc:	8b 44 24 14          	mov    0x14(%esp),%eax
c00264c0:	c6 00 00             	movb   $0x0,(%eax)
c00264c3:	83 c4 10             	add    $0x10,%esp
  return aux.length;
c00264c6:	8b 44 24 08          	mov    0x8(%esp),%eax
}
c00264ca:	83 c4 18             	add    $0x18,%esp
c00264cd:	5b                   	pop    %ebx
c00264ce:	c3                   	ret    
  aux.max_length = buf_size > 0 ? buf_size - 1 : 0;
c00264cf:	c7 44 24 0c 00 00 00 	movl   $0x0,0xc(%esp)
c00264d6:	00 
  __vprintf (format, args, vsnprintf_helper, &aux);
c00264d7:	8d 44 24 04          	lea    0x4(%esp),%eax
c00264db:	50                   	push   %eax
c00264dc:	68 13 59 02 c0       	push   $0xc0025913
c00264e1:	51                   	push   %ecx
c00264e2:	52                   	push   %edx
c00264e3:	e8 ae f8 ff ff       	call   c0025d96 <__vprintf>
c00264e8:	83 c4 10             	add    $0x10,%esp
c00264eb:	eb d9                	jmp    c00264c6 <vsnprintf+0x44>

c00264ed <snprintf>:
{
c00264ed:	83 ec 0c             	sub    $0xc,%esp
  va_start (args, format);
c00264f0:	8d 44 24 1c          	lea    0x1c(%esp),%eax
  retval = vsnprintf (buffer, buf_size, format, args);
c00264f4:	50                   	push   %eax
c00264f5:	ff 74 24 1c          	pushl  0x1c(%esp)
c00264f9:	ff 74 24 1c          	pushl  0x1c(%esp)
c00264fd:	ff 74 24 1c          	pushl  0x1c(%esp)
c0026501:	e8 7c ff ff ff       	call   c0026482 <vsnprintf>
}
c0026506:	83 c4 1c             	add    $0x1c,%esp
c0026509:	c3                   	ret    

c002650a <hex_dump>:
   starting at OFS for the first byte in BUF.  If ASCII is true
   then the corresponding ASCII characters are also rendered
   alongside. */   
void
hex_dump (uintptr_t ofs, const void *buf_, size_t size, bool ascii)
{
c002650a:	55                   	push   %ebp
c002650b:	57                   	push   %edi
c002650c:	56                   	push   %esi
c002650d:	53                   	push   %ebx
c002650e:	83 ec 1c             	sub    $0x1c,%esp
c0026511:	8a 44 24 3c          	mov    0x3c(%esp),%al
c0026515:	88 44 24 0f          	mov    %al,0xf(%esp)
  const uint8_t *buf = buf_;
  const size_t per_line = 16; /* Maximum bytes per line. */

  while (size > 0)
c0026519:	83 7c 24 38 00       	cmpl   $0x0,0x38(%esp)
c002651e:	0f 84 d9 01 00 00    	je     c00266fd <hex_dump+0x1f3>
c0026524:	8b 44 24 34          	mov    0x34(%esp),%eax
c0026528:	89 44 24 08          	mov    %eax,0x8(%esp)
c002652c:	e9 87 00 00 00       	jmp    c00265b8 <hex_dump+0xae>
      /* Number of bytes on this line. */
      start = ofs % per_line;
      end = per_line;
      if (end - start > size)
        end = start + size;
      n = end - start;
c0026531:	8b 44 24 38          	mov    0x38(%esp),%eax
c0026535:	89 44 24 04          	mov    %eax,0x4(%esp)

      /* Print line. */
      printf ("%08jx  ", (uintmax_t) ROUND_DOWN (ofs, per_line));
      for (i = 0; i < start; i++)
c0026539:	89 f3                	mov    %esi,%ebx
c002653b:	e9 e2 00 00 00       	jmp    c0026622 <hex_dump+0x118>
        printf ("   ");
      for (; i < end; i++) 
        printf ("%02hhx%c",
c0026540:	b8 2d 00 00 00       	mov    $0x2d,%eax
c0026545:	e9 f0 00 00 00       	jmp    c002663a <hex_dump+0x130>
            printf ("   ");
          printf ("|");
          for (i = 0; i < start; i++)
            printf (" ");
          for (; i < end; i++)
            printf ("%c",
c002654a:	83 ec 0c             	sub    $0xc,%esp
c002654d:	0f b6 c0             	movzbl %al,%eax
c0026550:	50                   	push   %eax
c0026551:	e8 73 2d 00 00       	call   c00292c9 <putchar>
          for (; i < end; i++)
c0026556:	43                   	inc    %ebx
c0026557:	83 c4 10             	add    $0x10,%esp
c002655a:	39 fb                	cmp    %edi,%ebx
c002655c:	73 12                	jae    c0026570 <hex_dump+0x66>
                    isprint (buf[i - start]) ? buf[i - start] : '.');
c002655e:	8a 04 1e             	mov    (%esi,%ebx,1),%al
static inline int isprint (int c) { return c >= 32 && c < 127; }
c0026561:	0f b6 d0             	movzbl %al,%edx
c0026564:	83 ea 20             	sub    $0x20,%edx
            printf ("%c",
c0026567:	83 fa 5e             	cmp    $0x5e,%edx
c002656a:	76 de                	jbe    c002654a <hex_dump+0x40>
c002656c:	89 e8                	mov    %ebp,%eax
c002656e:	eb da                	jmp    c002654a <hex_dump+0x40>
          for (; i < per_line; i++)
c0026570:	83 fb 0f             	cmp    $0xf,%ebx
c0026573:	77 13                	ja     c0026588 <hex_dump+0x7e>
            printf (" ");
c0026575:	83 ec 0c             	sub    $0xc,%esp
c0026578:	6a 20                	push   $0x20
c002657a:	e8 4a 2d 00 00       	call   c00292c9 <putchar>
          for (; i < per_line; i++)
c002657f:	43                   	inc    %ebx
c0026580:	83 c4 10             	add    $0x10,%esp
c0026583:	83 fb 0f             	cmp    $0xf,%ebx
c0026586:	76 ed                	jbe    c0026575 <hex_dump+0x6b>
          printf ("|");
c0026588:	83 ec 0c             	sub    $0xc,%esp
c002658b:	6a 7c                	push   $0x7c
c002658d:	e8 37 2d 00 00       	call   c00292c9 <putchar>
c0026592:	83 c4 10             	add    $0x10,%esp
        }
      printf ("\n");
c0026595:	83 ec 0c             	sub    $0xc,%esp
c0026598:	6a 0a                	push   $0xa
c002659a:	e8 2a 2d 00 00       	call   c00292c9 <putchar>

      ofs += n;
c002659f:	8b 44 24 14          	mov    0x14(%esp),%eax
c00265a3:	01 44 24 40          	add    %eax,0x40(%esp)
      buf += n;
c00265a7:	01 44 24 18          	add    %eax,0x18(%esp)
  while (size > 0)
c00265ab:	83 c4 10             	add    $0x10,%esp
c00265ae:	29 44 24 38          	sub    %eax,0x38(%esp)
c00265b2:	0f 84 45 01 00 00    	je     c00266fd <hex_dump+0x1f3>
      start = ofs % per_line;
c00265b8:	8b 74 24 30          	mov    0x30(%esp),%esi
c00265bc:	83 e6 0f             	and    $0xf,%esi
      if (end - start > size)
c00265bf:	b8 10 00 00 00       	mov    $0x10,%eax
c00265c4:	29 f0                	sub    %esi,%eax
c00265c6:	89 44 24 04          	mov    %eax,0x4(%esp)
c00265ca:	3b 44 24 38          	cmp    0x38(%esp),%eax
c00265ce:	0f 86 ea 00 00 00    	jbe    c00266be <hex_dump+0x1b4>
        end = start + size;
c00265d4:	89 f7                	mov    %esi,%edi
c00265d6:	03 7c 24 38          	add    0x38(%esp),%edi
      printf ("%08jx  ", (uintmax_t) ROUND_DOWN (ofs, per_line));
c00265da:	83 ec 04             	sub    $0x4,%esp
c00265dd:	8b 44 24 34          	mov    0x34(%esp),%eax
c00265e1:	83 e0 f0             	and    $0xfffffff0,%eax
c00265e4:	ba 00 00 00 00       	mov    $0x0,%edx
c00265e9:	52                   	push   %edx
c00265ea:	50                   	push   %eax
c00265eb:	68 dc e4 02 c0       	push   $0xc002e4dc
c00265f0:	e8 6c f7 ff ff       	call   c0025d61 <printf>
      for (i = 0; i < start; i++)
c00265f5:	83 c4 10             	add    $0x10,%esp
c00265f8:	85 f6                	test   %esi,%esi
c00265fa:	0f 84 31 ff ff ff    	je     c0026531 <hex_dump+0x27>
      n = end - start;
c0026600:	8b 44 24 38          	mov    0x38(%esp),%eax
c0026604:	89 44 24 04          	mov    %eax,0x4(%esp)
      end = per_line;
c0026608:	bb 00 00 00 00       	mov    $0x0,%ebx
        printf ("   ");
c002660d:	83 ec 0c             	sub    $0xc,%esp
c0026610:	68 e4 e4 02 c0       	push   $0xc002e4e4
c0026615:	e8 47 f7 ff ff       	call   c0025d61 <printf>
      for (i = 0; i < start; i++)
c002661a:	43                   	inc    %ebx
c002661b:	83 c4 10             	add    $0x10,%esp
c002661e:	39 de                	cmp    %ebx,%esi
c0026620:	77 eb                	ja     c002660d <hex_dump+0x103>
      for (; i < end; i++) 
c0026622:	39 fb                	cmp    %edi,%ebx
c0026624:	73 30                	jae    c0026656 <hex_dump+0x14c>
                buf[i - start], i == per_line / 2 - 1? '-' : ' ');
c0026626:	8b 6c 24 08          	mov    0x8(%esp),%ebp
c002662a:	29 f5                	sub    %esi,%ebp
        printf ("%02hhx%c",
c002662c:	83 fb 07             	cmp    $0x7,%ebx
c002662f:	0f 84 0b ff ff ff    	je     c0026540 <hex_dump+0x36>
c0026635:	b8 20 00 00 00       	mov    $0x20,%eax
c002663a:	83 ec 04             	sub    $0x4,%esp
c002663d:	50                   	push   %eax
c002663e:	0f b6 44 1d 00       	movzbl 0x0(%ebp,%ebx,1),%eax
c0026643:	50                   	push   %eax
c0026644:	68 e8 e4 02 c0       	push   $0xc002e4e8
c0026649:	e8 13 f7 ff ff       	call   c0025d61 <printf>
      for (; i < end; i++) 
c002664e:	43                   	inc    %ebx
c002664f:	83 c4 10             	add    $0x10,%esp
c0026652:	39 fb                	cmp    %edi,%ebx
c0026654:	72 d6                	jb     c002662c <hex_dump+0x122>
      if (ascii) 
c0026656:	80 7c 24 0f 00       	cmpb   $0x0,0xf(%esp)
c002665b:	0f 84 34 ff ff ff    	je     c0026595 <hex_dump+0x8b>
          for (; i < per_line; i++)
c0026661:	83 fb 0f             	cmp    $0xf,%ebx
c0026664:	77 16                	ja     c002667c <hex_dump+0x172>
            printf ("   ");
c0026666:	83 ec 0c             	sub    $0xc,%esp
c0026669:	68 e4 e4 02 c0       	push   $0xc002e4e4
c002666e:	e8 ee f6 ff ff       	call   c0025d61 <printf>
          for (; i < per_line; i++)
c0026673:	43                   	inc    %ebx
c0026674:	83 c4 10             	add    $0x10,%esp
c0026677:	83 fb 10             	cmp    $0x10,%ebx
c002667a:	75 ea                	jne    c0026666 <hex_dump+0x15c>
          printf ("|");
c002667c:	83 ec 0c             	sub    $0xc,%esp
c002667f:	6a 7c                	push   $0x7c
c0026681:	e8 43 2c 00 00       	call   c00292c9 <putchar>
          for (i = 0; i < start; i++)
c0026686:	83 c4 10             	add    $0x10,%esp
c0026689:	85 f6                	test   %esi,%esi
c002668b:	74 63                	je     c00266f0 <hex_dump+0x1e6>
c002668d:	bb 00 00 00 00       	mov    $0x0,%ebx
            printf (" ");
c0026692:	83 ec 0c             	sub    $0xc,%esp
c0026695:	6a 20                	push   $0x20
c0026697:	e8 2d 2c 00 00       	call   c00292c9 <putchar>
          for (i = 0; i < start; i++)
c002669c:	43                   	inc    %ebx
c002669d:	83 c4 10             	add    $0x10,%esp
c00266a0:	39 de                	cmp    %ebx,%esi
c00266a2:	75 ee                	jne    c0026692 <hex_dump+0x188>
          for (; i < end; i++)
c00266a4:	39 fb                	cmp    %edi,%ebx
c00266a6:	0f 83 c4 fe ff ff    	jae    c0026570 <hex_dump+0x66>
                    isprint (buf[i - start]) ? buf[i - start] : '.');
c00266ac:	8b 44 24 08          	mov    0x8(%esp),%eax
c00266b0:	29 f0                	sub    %esi,%eax
c00266b2:	89 c6                	mov    %eax,%esi
c00266b4:	bd 2e 00 00 00       	mov    $0x2e,%ebp
c00266b9:	e9 a0 fe ff ff       	jmp    c002655e <hex_dump+0x54>
      printf ("%08jx  ", (uintmax_t) ROUND_DOWN (ofs, per_line));
c00266be:	83 ec 04             	sub    $0x4,%esp
c00266c1:	8b 44 24 34          	mov    0x34(%esp),%eax
c00266c5:	83 e0 f0             	and    $0xfffffff0,%eax
c00266c8:	ba 00 00 00 00       	mov    $0x0,%edx
c00266cd:	52                   	push   %edx
c00266ce:	50                   	push   %eax
c00266cf:	68 dc e4 02 c0       	push   $0xc002e4dc
c00266d4:	e8 88 f6 ff ff       	call   c0025d61 <printf>
      for (i = 0; i < start; i++)
c00266d9:	83 c4 10             	add    $0x10,%esp
      end = per_line;
c00266dc:	bf 10 00 00 00       	mov    $0x10,%edi
      for (i = 0; i < start; i++)
c00266e1:	89 f3                	mov    %esi,%ebx
c00266e3:	85 f6                	test   %esi,%esi
c00266e5:	0f 85 1d ff ff ff    	jne    c0026608 <hex_dump+0xfe>
c00266eb:	e9 36 ff ff ff       	jmp    c0026626 <hex_dump+0x11c>
          for (i = 0; i < start; i++)
c00266f0:	89 f3                	mov    %esi,%ebx
          for (; i < end; i++)
c00266f2:	85 ff                	test   %edi,%edi
c00266f4:	75 b6                	jne    c00266ac <hex_dump+0x1a2>
          for (i = 0; i < start; i++)
c00266f6:	89 fb                	mov    %edi,%ebx
c00266f8:	e9 78 fe ff ff       	jmp    c0026575 <hex_dump+0x6b>
      size -= n;
    }
}
c00266fd:	83 c4 1c             	add    $0x1c,%esp
c0026700:	5b                   	pop    %ebx
c0026701:	5e                   	pop    %esi
c0026702:	5f                   	pop    %edi
c0026703:	5d                   	pop    %ebp
c0026704:	c3                   	ret    

c0026705 <print_human_readable_size>:

/* Prints SIZE, which represents a number of bytes, in a
   human-readable format, e.g. "256 kB". */
void
print_human_readable_size (uint64_t size) 
{
c0026705:	57                   	push   %edi
c0026706:	56                   	push   %esi
c0026707:	83 ec 04             	sub    $0x4,%esp
c002670a:	8b 74 24 10          	mov    0x10(%esp),%esi
c002670e:	8b 7c 24 14          	mov    0x14(%esp),%edi
  if (size == 1)
c0026712:	89 f0                	mov    %esi,%eax
c0026714:	83 f0 01             	xor    $0x1,%eax
c0026717:	89 fa                	mov    %edi,%edx
c0026719:	09 c2                	or     %eax,%edx
c002671b:	74 1d                	je     c002673a <print_human_readable_size+0x35>
  else 
    {
      static const char *factors[] = {"bytes", "kB", "MB", "GB", "TB", NULL};
      const char **fp;

      for (fp = factors; size >= 1024 && fp[1] != NULL; fp++)
c002671d:	83 ff 00             	cmp    $0x0,%edi
c0026720:	77 08                	ja     c002672a <print_human_readable_size+0x25>
c0026722:	81 fe ff 03 00 00    	cmp    $0x3ff,%esi
c0026728:	76 5d                	jbe    c0026787 <print_human_readable_size+0x82>
c002672a:	b9 ec 68 03 c0       	mov    $0xc00368ec,%ecx
c002672f:	83 3d f0 68 03 c0 00 	cmpl   $0x0,0xc00368f0
c0026736:	75 1a                	jne    c0026752 <print_human_readable_size+0x4d>
c0026738:	eb 36                	jmp    c0026770 <print_human_readable_size+0x6b>
    printf ("1 byte");
c002673a:	83 ec 0c             	sub    $0xc,%esp
c002673d:	68 f1 e4 02 c0       	push   $0xc002e4f1
c0026742:	e8 1a f6 ff ff       	call   c0025d61 <printf>
c0026747:	83 c4 10             	add    $0x10,%esp
c002674a:	eb 35                	jmp    c0026781 <print_human_readable_size+0x7c>
      for (fp = factors; size >= 1024 && fp[1] != NULL; fp++)
c002674c:	83 79 04 00          	cmpl   $0x0,0x4(%ecx)
c0026750:	74 1e                	je     c0026770 <print_human_readable_size+0x6b>
        size /= 1024;
c0026752:	89 f0                	mov    %esi,%eax
c0026754:	89 fa                	mov    %edi,%edx
c0026756:	0f ac f8 0a          	shrd   $0xa,%edi,%eax
c002675a:	c1 ea 0a             	shr    $0xa,%edx
c002675d:	89 c6                	mov    %eax,%esi
c002675f:	89 d7                	mov    %edx,%edi
      for (fp = factors; size >= 1024 && fp[1] != NULL; fp++)
c0026761:	83 c1 04             	add    $0x4,%ecx
c0026764:	83 fa 00             	cmp    $0x0,%edx
c0026767:	77 e3                	ja     c002674c <print_human_readable_size+0x47>
c0026769:	3d ff 03 00 00       	cmp    $0x3ff,%eax
c002676e:	77 dc                	ja     c002674c <print_human_readable_size+0x47>
      printf ("%"PRIu64" %s", size, *fp);
c0026770:	ff 31                	pushl  (%ecx)
c0026772:	57                   	push   %edi
c0026773:	56                   	push   %esi
c0026774:	68 f8 e4 02 c0       	push   $0xc002e4f8
c0026779:	e8 e3 f5 ff ff       	call   c0025d61 <printf>
c002677e:	83 c4 10             	add    $0x10,%esp
    }
}
c0026781:	83 c4 04             	add    $0x4,%esp
c0026784:	5e                   	pop    %esi
c0026785:	5f                   	pop    %edi
c0026786:	c3                   	ret    
      for (fp = factors; size >= 1024 && fp[1] != NULL; fp++)
c0026787:	b9 ec 68 03 c0       	mov    $0xc00368ec,%ecx
c002678c:	eb e2                	jmp    c0026770 <print_human_readable_size+0x6b>

c002678e <compare_thunk>:
}

/* Compares A and B by calling the AUX function. */
static int
compare_thunk (const void *a, const void *b, void *aux) 
{
c002678e:	83 ec 14             	sub    $0x14,%esp
  int (**compare) (const void *, const void *) = aux;
  return (*compare) (a, b);
c0026791:	ff 74 24 1c          	pushl  0x1c(%esp)
c0026795:	ff 74 24 1c          	pushl  0x1c(%esp)
c0026799:	8b 44 24 28          	mov    0x28(%esp),%eax
c002679d:	ff 10                	call   *(%eax)
}
c002679f:	83 c4 1c             	add    $0x1c,%esp
c00267a2:	c3                   	ret    

c00267a3 <do_swap>:

/* Swaps elements with 1-based indexes A_IDX and B_IDX in ARRAY
   with elements of SIZE bytes each. */
static void
do_swap (unsigned char *array, size_t a_idx, size_t b_idx, size_t size)
{
c00267a3:	55                   	push   %ebp
c00267a4:	57                   	push   %edi
c00267a5:	56                   	push   %esi
c00267a6:	53                   	push   %ebx
c00267a7:	8b 7c 24 14          	mov    0x14(%esp),%edi
  unsigned char *a = array + (a_idx - 1) * size;
c00267ab:	8d 72 ff             	lea    -0x1(%edx),%esi
c00267ae:	0f af f7             	imul   %edi,%esi
  unsigned char *b = array + (b_idx - 1) * size;
c00267b1:	8d 59 ff             	lea    -0x1(%ecx),%ebx
c00267b4:	0f af df             	imul   %edi,%ebx
  size_t i;

  for (i = 0; i < size; i++)
c00267b7:	85 ff                	test   %edi,%edi
c00267b9:	74 1d                	je     c00267d8 <do_swap+0x35>
c00267bb:	8d 14 30             	lea    (%eax,%esi,1),%edx
c00267be:	01 f7                	add    %esi,%edi
c00267c0:	01 c7                	add    %eax,%edi
    {
      unsigned char t = a[i];
c00267c2:	0f b6 2a             	movzbl (%edx),%ebp
c00267c5:	89 d1                	mov    %edx,%ecx
c00267c7:	29 f1                	sub    %esi,%ecx
      a[i] = b[i];
c00267c9:	8a 04 19             	mov    (%ecx,%ebx,1),%al
c00267cc:	88 02                	mov    %al,(%edx)
      b[i] = t;
c00267ce:	89 e8                	mov    %ebp,%eax
c00267d0:	88 04 19             	mov    %al,(%ecx,%ebx,1)
c00267d3:	42                   	inc    %edx
  for (i = 0; i < size; i++)
c00267d4:	39 fa                	cmp    %edi,%edx
c00267d6:	75 ea                	jne    c00267c2 <do_swap+0x1f>
    }
}
c00267d8:	5b                   	pop    %ebx
c00267d9:	5e                   	pop    %esi
c00267da:	5f                   	pop    %edi
c00267db:	5d                   	pop    %ebp
c00267dc:	c3                   	ret    

c00267dd <heapify>:
   elements, passing AUX as auxiliary data. */
static void
heapify (unsigned char *array, size_t i, size_t cnt, size_t size,
         int (*compare) (const void *, const void *, void *aux),
         void *aux) 
{
c00267dd:	55                   	push   %ebp
c00267de:	57                   	push   %edi
c00267df:	56                   	push   %esi
c00267e0:	53                   	push   %ebx
c00267e1:	83 ec 1c             	sub    $0x1c,%esp
c00267e4:	89 44 24 0c          	mov    %eax,0xc(%esp)
c00267e8:	89 d6                	mov    %edx,%esi
c00267ea:	89 4c 24 08          	mov    %ecx,0x8(%esp)
c00267ee:	8b 6c 24 30          	mov    0x30(%esp),%ebp
c00267f2:	eb 4a                	jmp    c002683e <heapify+0x61>
  return compare (array + (a_idx - 1) * size, array + (b_idx - 1) * size, aux);
c00267f4:	83 ec 04             	sub    $0x4,%esp
c00267f7:	ff 74 24 3c          	pushl  0x3c(%esp)
c00267fb:	8d 46 ff             	lea    -0x1(%esi),%eax
c00267fe:	0f af c5             	imul   %ebp,%eax
c0026801:	8b 4c 24 14          	mov    0x14(%esp),%ecx
c0026805:	01 c8                	add    %ecx,%eax
c0026807:	50                   	push   %eax
c0026808:	8d 43 ff             	lea    -0x1(%ebx),%eax
c002680b:	0f af c5             	imul   %ebp,%eax
c002680e:	01 c8                	add    %ecx,%eax
c0026810:	50                   	push   %eax
c0026811:	ff 54 24 44          	call   *0x44(%esp)
      /* Set `max' to the index of the largest element among I
         and its children (if any). */
      size_t left = 2 * i;
      size_t right = 2 * i + 1;
      size_t max = i;
      if (left <= cnt && do_compare (array, left, max, size, compare, aux) > 0)
c0026815:	83 c4 10             	add    $0x10,%esp
c0026818:	85 c0                	test   %eax,%eax
c002681a:	7e 2e                	jle    c002684a <heapify+0x6d>
        max = left;
      if (right <= cnt
c002681c:	3b 7c 24 08          	cmp    0x8(%esp),%edi
c0026820:	76 5b                	jbe    c002687d <heapify+0xa0>
        max = left;
c0026822:	89 df                	mov    %ebx,%edi
          && do_compare (array, right, max, size, compare, aux) > 0) 
        max = right;

      /* If the maximum value is already in element I, we're
         done. */
      if (max == i)
c0026824:	39 fe                	cmp    %edi,%esi
c0026826:	74 4d                	je     c0026875 <heapify+0x98>
        break;

      /* Swap and continue down the heap. */
      do_swap (array, i, max, size);
c0026828:	83 ec 0c             	sub    $0xc,%esp
c002682b:	55                   	push   %ebp
c002682c:	89 f9                	mov    %edi,%ecx
c002682e:	89 f2                	mov    %esi,%edx
c0026830:	8b 44 24 1c          	mov    0x1c(%esp),%eax
c0026834:	e8 6a ff ff ff       	call   c00267a3 <do_swap>
c0026839:	89 fe                	mov    %edi,%esi
    {
c002683b:	83 c4 10             	add    $0x10,%esp
      size_t left = 2 * i;
c002683e:	8d 1c 36             	lea    (%esi,%esi,1),%ebx
      size_t right = 2 * i + 1;
c0026841:	8d 7b 01             	lea    0x1(%ebx),%edi
      if (left <= cnt && do_compare (array, left, max, size, compare, aux) > 0)
c0026844:	3b 5c 24 08          	cmp    0x8(%esp),%ebx
c0026848:	76 aa                	jbe    c00267f4 <heapify+0x17>
      if (right <= cnt
c002684a:	3b 7c 24 08          	cmp    0x8(%esp),%edi
c002684e:	77 25                	ja     c0026875 <heapify+0x98>
  return compare (array + (a_idx - 1) * size, array + (b_idx - 1) * size, aux);
c0026850:	83 ec 04             	sub    $0x4,%esp
c0026853:	ff 74 24 3c          	pushl  0x3c(%esp)
c0026857:	8d 46 ff             	lea    -0x1(%esi),%eax
c002685a:	0f af c5             	imul   %ebp,%eax
c002685d:	8b 54 24 14          	mov    0x14(%esp),%edx
c0026861:	01 d0                	add    %edx,%eax
c0026863:	50                   	push   %eax
c0026864:	0f af dd             	imul   %ebp,%ebx
c0026867:	01 d3                	add    %edx,%ebx
c0026869:	53                   	push   %ebx
c002686a:	ff 54 24 44          	call   *0x44(%esp)
          && do_compare (array, right, max, size, compare, aux) > 0) 
c002686e:	83 c4 10             	add    $0x10,%esp
c0026871:	85 c0                	test   %eax,%eax
c0026873:	7f af                	jg     c0026824 <heapify+0x47>
      i = max;
    }
}
c0026875:	83 c4 1c             	add    $0x1c,%esp
c0026878:	5b                   	pop    %ebx
c0026879:	5e                   	pop    %esi
c002687a:	5f                   	pop    %edi
c002687b:	5d                   	pop    %ebp
c002687c:	c3                   	ret    
  return compare (array + (a_idx - 1) * size, array + (b_idx - 1) * size, aux);
c002687d:	83 ec 04             	sub    $0x4,%esp
c0026880:	ff 74 24 3c          	pushl  0x3c(%esp)
c0026884:	8d 43 ff             	lea    -0x1(%ebx),%eax
c0026887:	0f af c5             	imul   %ebp,%eax
c002688a:	8b 4c 24 14          	mov    0x14(%esp),%ecx
c002688e:	01 c8                	add    %ecx,%eax
c0026890:	50                   	push   %eax
c0026891:	89 d8                	mov    %ebx,%eax
c0026893:	0f af c5             	imul   %ebp,%eax
c0026896:	01 c8                	add    %ecx,%eax
c0026898:	50                   	push   %eax
c0026899:	ff 54 24 44          	call   *0x44(%esp)
          && do_compare (array, right, max, size, compare, aux) > 0) 
c002689d:	83 c4 10             	add    $0x10,%esp
c00268a0:	85 c0                	test   %eax,%eax
c00268a2:	7f 80                	jg     c0026824 <heapify+0x47>
        max = left;
c00268a4:	89 df                	mov    %ebx,%edi
c00268a6:	e9 79 ff ff ff       	jmp    c0026824 <heapify+0x47>

c00268ab <atoi>:
{
c00268ab:	56                   	push   %esi
c00268ac:	53                   	push   %ebx
c00268ad:	83 ec 04             	sub    $0x4,%esp
c00268b0:	8b 54 24 10          	mov    0x10(%esp),%edx
  ASSERT (s != NULL);
c00268b4:	85 d2                	test   %edx,%edx
c00268b6:	75 1f                	jne    c00268d7 <atoi+0x2c>
c00268b8:	83 ec 0c             	sub    $0xc,%esp
c00268bb:	68 97 e5 02 c0       	push   $0xc002e597
c00268c0:	68 9f cd 02 c0       	push   $0xc002cd9f
c00268c5:	68 58 c8 02 c0       	push   $0xc002c858
c00268ca:	6a 0f                	push   $0xf
c00268cc:	68 48 e5 02 c0       	push   $0xc002e548
c00268d1:	e8 39 0f 00 00       	call   c002780f <debug_panic>
    s++;
c00268d6:	42                   	inc    %edx
  while (isspace ((unsigned char) *s))
c00268d7:	8a 02                	mov    (%edx),%al
          || c == '\r' || c == '\t' || c == '\v');
c00268d9:	3c 20                	cmp    $0x20,%al
c00268db:	74 f9                	je     c00268d6 <atoi+0x2b>
c00268dd:	8d 48 f7             	lea    -0x9(%eax),%ecx
c00268e0:	80 f9 04             	cmp    $0x4,%cl
c00268e3:	76 f1                	jbe    c00268d6 <atoi+0x2b>
  if (*s == '+')
c00268e5:	3c 2b                	cmp    $0x2b,%al
c00268e7:	74 3e                	je     c0026927 <atoi+0x7c>
  else if (*s == '-')
c00268e9:	3c 2d                	cmp    $0x2d,%al
c00268eb:	74 3d                	je     c002692a <atoi+0x7f>
  for (value = 0; isdigit (*s); s++)
c00268ed:	0f be 0a             	movsbl (%edx),%ecx
static inline int isdigit (int c) { return c >= '0' && c <= '9'; }
c00268f0:	8d 41 d0             	lea    -0x30(%ecx),%eax
c00268f3:	be 00 00 00 00       	mov    $0x0,%esi
c00268f8:	83 f8 09             	cmp    $0x9,%eax
c00268fb:	77 4c                	ja     c0026949 <atoi+0x9e>
      negative = true;
c00268fd:	b8 00 00 00 00       	mov    $0x0,%eax
    value = value * 10 - (*s - '0');
c0026902:	8d 04 80             	lea    (%eax,%eax,4),%eax
c0026905:	89 c3                	mov    %eax,%ebx
c0026907:	29 cb                	sub    %ecx,%ebx
c0026909:	8d 44 03 30          	lea    0x30(%ebx,%eax,1),%eax
  for (value = 0; isdigit (*s); s++)
c002690d:	42                   	inc    %edx
c002690e:	0f be 0a             	movsbl (%edx),%ecx
c0026911:	8d 59 d0             	lea    -0x30(%ecx),%ebx
c0026914:	83 fb 09             	cmp    $0x9,%ebx
c0026917:	76 e9                	jbe    c0026902 <atoi+0x57>
  if (!negative)
c0026919:	89 f3                	mov    %esi,%ebx
c002691b:	84 db                	test   %bl,%bl
c002691d:	75 02                	jne    c0026921 <atoi+0x76>
    value = -value;
c002691f:	f7 d8                	neg    %eax
}
c0026921:	83 c4 04             	add    $0x4,%esp
c0026924:	5b                   	pop    %ebx
c0026925:	5e                   	pop    %esi
c0026926:	c3                   	ret    
    s++;
c0026927:	42                   	inc    %edx
c0026928:	eb c3                	jmp    c00268ed <atoi+0x42>
      s++;
c002692a:	8d 42 01             	lea    0x1(%edx),%eax
  for (value = 0; isdigit (*s); s++)
c002692d:	0f be 4a 01          	movsbl 0x1(%edx),%ecx
c0026931:	8d 51 d0             	lea    -0x30(%ecx),%edx
c0026934:	83 fa 09             	cmp    $0x9,%edx
c0026937:	77 09                	ja     c0026942 <atoi+0x97>
      s++;
c0026939:	89 c2                	mov    %eax,%edx
      negative = true;
c002693b:	be 01 00 00 00       	mov    $0x1,%esi
c0026940:	eb bb                	jmp    c00268fd <atoi+0x52>
  for (value = 0; isdigit (*s); s++)
c0026942:	b8 00 00 00 00       	mov    $0x0,%eax
  return value;
c0026947:	eb d8                	jmp    c0026921 <atoi+0x76>
  for (value = 0; isdigit (*s); s++)
c0026949:	b8 00 00 00 00       	mov    $0x0,%eax
c002694e:	eb cf                	jmp    c002691f <atoi+0x74>

c0026950 <sort>:
   B.  Runs in O(n lg n) time and O(1) space in CNT. */
void
sort (void *array, size_t cnt, size_t size,
      int (*compare) (const void *, const void *, void *aux),
      void *aux) 
{
c0026950:	55                   	push   %ebp
c0026951:	57                   	push   %edi
c0026952:	56                   	push   %esi
c0026953:	53                   	push   %ebx
c0026954:	83 ec 0c             	sub    $0xc,%esp
c0026957:	8b 5c 24 24          	mov    0x24(%esp),%ebx
c002695b:	8b 7c 24 28          	mov    0x28(%esp),%edi
c002695f:	8b 6c 24 2c          	mov    0x2c(%esp),%ebp
c0026963:	8b 74 24 30          	mov    0x30(%esp),%esi
  size_t i;

  ASSERT (array != NULL || cnt == 0);
c0026967:	83 7c 24 20 00       	cmpl   $0x0,0x20(%esp)
c002696c:	74 7b                	je     c00269e9 <sort+0x99>
  ASSERT (compare != NULL);
c002696e:	85 ed                	test   %ebp,%ebp
c0026970:	0f 84 98 00 00 00    	je     c0026a0e <sort+0xbe>
  ASSERT (size > 0);
c0026976:	85 ff                	test   %edi,%edi
c0026978:	0f 84 b1 00 00 00    	je     c0026a2f <sort+0xdf>

  /* Build a heap. */
  for (i = cnt / 2; i > 0; i--)
c002697e:	89 d8                	mov    %ebx,%eax
c0026980:	d1 e8                	shr    %eax
c0026982:	74 25                	je     c00269a9 <sort+0x59>
c0026984:	89 5c 24 24          	mov    %ebx,0x24(%esp)
c0026988:	89 c3                	mov    %eax,%ebx
    heapify (array, i, cnt, size, compare, aux);
c002698a:	83 ec 04             	sub    $0x4,%esp
c002698d:	56                   	push   %esi
c002698e:	55                   	push   %ebp
c002698f:	57                   	push   %edi
c0026990:	8b 4c 24 34          	mov    0x34(%esp),%ecx
c0026994:	89 da                	mov    %ebx,%edx
c0026996:	8b 44 24 30          	mov    0x30(%esp),%eax
c002699a:	e8 3e fe ff ff       	call   c00267dd <heapify>
  for (i = cnt / 2; i > 0; i--)
c002699f:	83 c4 10             	add    $0x10,%esp
c00269a2:	4b                   	dec    %ebx
c00269a3:	75 e5                	jne    c002698a <sort+0x3a>
c00269a5:	8b 5c 24 24          	mov    0x24(%esp),%ebx

  /* Sort the heap. */
  for (i = cnt; i > 1; i--) 
c00269a9:	83 fb 01             	cmp    $0x1,%ebx
c00269ac:	76 33                	jbe    c00269e1 <sort+0x91>
    {
      do_swap (array, 1, i, size);
c00269ae:	83 ec 0c             	sub    $0xc,%esp
c00269b1:	57                   	push   %edi
c00269b2:	89 d9                	mov    %ebx,%ecx
c00269b4:	ba 01 00 00 00       	mov    $0x1,%edx
c00269b9:	8b 44 24 30          	mov    0x30(%esp),%eax
c00269bd:	e8 e1 fd ff ff       	call   c00267a3 <do_swap>
      heapify (array, 1, i - 1, size, compare, aux); 
c00269c2:	4b                   	dec    %ebx
c00269c3:	83 c4 0c             	add    $0xc,%esp
c00269c6:	56                   	push   %esi
c00269c7:	55                   	push   %ebp
c00269c8:	57                   	push   %edi
c00269c9:	89 d9                	mov    %ebx,%ecx
c00269cb:	ba 01 00 00 00       	mov    $0x1,%edx
c00269d0:	8b 44 24 30          	mov    0x30(%esp),%eax
c00269d4:	e8 04 fe ff ff       	call   c00267dd <heapify>
  for (i = cnt; i > 1; i--) 
c00269d9:	83 c4 10             	add    $0x10,%esp
c00269dc:	83 fb 01             	cmp    $0x1,%ebx
c00269df:	75 cd                	jne    c00269ae <sort+0x5e>
    }
}
c00269e1:	83 c4 0c             	add    $0xc,%esp
c00269e4:	5b                   	pop    %ebx
c00269e5:	5e                   	pop    %esi
c00269e6:	5f                   	pop    %edi
c00269e7:	5d                   	pop    %ebp
c00269e8:	c3                   	ret    
  ASSERT (array != NULL || cnt == 0);
c00269e9:	85 db                	test   %ebx,%ebx
c00269eb:	74 81                	je     c002696e <sort+0x1e>
c00269ed:	83 ec 0c             	sub    $0xc,%esp
c00269f0:	68 5b e5 02 c0       	push   $0xc002e55b
c00269f5:	68 9f cd 02 c0       	push   $0xc002cd9f
c00269fa:	68 50 c8 02 c0       	push   $0xc002c850
c00269ff:	68 8a 00 00 00       	push   $0x8a
c0026a04:	68 48 e5 02 c0       	push   $0xc002e548
c0026a09:	e8 01 0e 00 00       	call   c002780f <debug_panic>
  ASSERT (compare != NULL);
c0026a0e:	83 ec 0c             	sub    $0xc,%esp
c0026a11:	68 75 e5 02 c0       	push   $0xc002e575
c0026a16:	68 9f cd 02 c0       	push   $0xc002cd9f
c0026a1b:	68 50 c8 02 c0       	push   $0xc002c850
c0026a20:	68 8b 00 00 00       	push   $0x8b
c0026a25:	68 48 e5 02 c0       	push   $0xc002e548
c0026a2a:	e8 e0 0d 00 00       	call   c002780f <debug_panic>
  ASSERT (size > 0);
c0026a2f:	83 ec 0c             	sub    $0xc,%esp
c0026a32:	68 85 e5 02 c0       	push   $0xc002e585
c0026a37:	68 9f cd 02 c0       	push   $0xc002cd9f
c0026a3c:	68 50 c8 02 c0       	push   $0xc002c850
c0026a41:	68 8c 00 00 00       	push   $0x8c
c0026a46:	68 48 e5 02 c0       	push   $0xc002e548
c0026a4b:	e8 bf 0d 00 00       	call   c002780f <debug_panic>

c0026a50 <qsort>:
{
c0026a50:	83 ec 18             	sub    $0x18,%esp
  sort (array, cnt, size, compare_thunk, &compare);
c0026a53:	8d 44 24 28          	lea    0x28(%esp),%eax
c0026a57:	50                   	push   %eax
c0026a58:	68 8e 67 02 c0       	push   $0xc002678e
c0026a5d:	ff 74 24 2c          	pushl  0x2c(%esp)
c0026a61:	ff 74 24 2c          	pushl  0x2c(%esp)
c0026a65:	ff 74 24 2c          	pushl  0x2c(%esp)
c0026a69:	e8 e2 fe ff ff       	call   c0026950 <sort>
}
c0026a6e:	83 c4 2c             	add    $0x2c,%esp
c0026a71:	c3                   	ret    

c0026a72 <binary_search>:
   B. */
void *
binary_search (const void *key, const void *array, size_t cnt, size_t size,
               int (*compare) (const void *, const void *, void *aux),
               void *aux) 
{
c0026a72:	55                   	push   %ebp
c0026a73:	57                   	push   %edi
c0026a74:	56                   	push   %esi
c0026a75:	53                   	push   %ebx
c0026a76:	83 ec 0c             	sub    $0xc,%esp
c0026a79:	8b 74 24 24          	mov    0x24(%esp),%esi
c0026a7d:	8b 7c 24 2c          	mov    0x2c(%esp),%edi
  const unsigned char *first = array;
  const unsigned char *last = array + size * cnt;
c0026a81:	89 fd                	mov    %edi,%ebp
c0026a83:	0f af 6c 24 28       	imul   0x28(%esp),%ebp
c0026a88:	01 f5                	add    %esi,%ebp

  while (first < last) 
c0026a8a:	39 ee                	cmp    %ebp,%esi
c0026a8c:	72 0d                	jb     c0026a9b <binary_search+0x29>
        first = middle + size;
      else
        return (void *) middle;
    }
  
  return NULL;
c0026a8e:	b8 00 00 00 00       	mov    $0x0,%eax
c0026a93:	eb 3e                	jmp    c0026ad3 <binary_search+0x61>
      const unsigned char *middle = first + (range / 2) * size;
c0026a95:	89 dd                	mov    %ebx,%ebp
  while (first < last) 
c0026a97:	39 ee                	cmp    %ebp,%esi
c0026a99:	73 33                	jae    c0026ace <binary_search+0x5c>
      size_t range = (last - first) / size;
c0026a9b:	89 e8                	mov    %ebp,%eax
c0026a9d:	29 f0                	sub    %esi,%eax
c0026a9f:	ba 00 00 00 00       	mov    $0x0,%edx
c0026aa4:	f7 f7                	div    %edi
      const unsigned char *middle = first + (range / 2) * size;
c0026aa6:	d1 e8                	shr    %eax
c0026aa8:	0f af c7             	imul   %edi,%eax
c0026aab:	8d 1c 06             	lea    (%esi,%eax,1),%ebx
      int cmp = compare (key, middle, aux);
c0026aae:	83 ec 04             	sub    $0x4,%esp
c0026ab1:	ff 74 24 38          	pushl  0x38(%esp)
c0026ab5:	53                   	push   %ebx
c0026ab6:	ff 74 24 2c          	pushl  0x2c(%esp)
c0026aba:	ff 54 24 40          	call   *0x40(%esp)
      if (cmp < 0) 
c0026abe:	83 c4 10             	add    $0x10,%esp
c0026ac1:	85 c0                	test   %eax,%eax
c0026ac3:	78 d0                	js     c0026a95 <binary_search+0x23>
      else if (cmp > 0) 
c0026ac5:	85 c0                	test   %eax,%eax
c0026ac7:	7e 12                	jle    c0026adb <binary_search+0x69>
        first = middle + size;
c0026ac9:	8d 34 3b             	lea    (%ebx,%edi,1),%esi
c0026acc:	eb c9                	jmp    c0026a97 <binary_search+0x25>
  return NULL;
c0026ace:	b8 00 00 00 00       	mov    $0x0,%eax
}
c0026ad3:	83 c4 0c             	add    $0xc,%esp
c0026ad6:	5b                   	pop    %ebx
c0026ad7:	5e                   	pop    %esi
c0026ad8:	5f                   	pop    %edi
c0026ad9:	5d                   	pop    %ebp
c0026ada:	c3                   	ret    
      const unsigned char *middle = first + (range / 2) * size;
c0026adb:	89 d8                	mov    %ebx,%eax
c0026add:	eb f4                	jmp    c0026ad3 <binary_search+0x61>

c0026adf <bsearch>:
{
c0026adf:	83 ec 14             	sub    $0x14,%esp
  return binary_search (key, array, cnt, size, compare_thunk, &compare);
c0026ae2:	8d 44 24 28          	lea    0x28(%esp),%eax
c0026ae6:	50                   	push   %eax
c0026ae7:	68 8e 67 02 c0       	push   $0xc002678e
c0026aec:	ff 74 24 2c          	pushl  0x2c(%esp)
c0026af0:	ff 74 24 2c          	pushl  0x2c(%esp)
c0026af4:	ff 74 24 2c          	pushl  0x2c(%esp)
c0026af8:	ff 74 24 2c          	pushl  0x2c(%esp)
c0026afc:	e8 71 ff ff ff       	call   c0026a72 <binary_search>
}
c0026b01:	83 c4 2c             	add    $0x2c,%esp
c0026b04:	c3                   	ret    

c0026b05 <memcpy>:

/* Copies SIZE bytes from SRC to DST, which must not overlap.
   Returns DST. */
void *
memcpy (void *dst_, const void *src_, size_t size) 
{
c0026b05:	56                   	push   %esi
c0026b06:	53                   	push   %ebx
c0026b07:	8b 44 24 0c          	mov    0xc(%esp),%eax
c0026b0b:	8b 5c 24 10          	mov    0x10(%esp),%ebx
c0026b0f:	8b 74 24 14          	mov    0x14(%esp),%esi
  const unsigned char *src = src_;

  ASSERT (dst != NULL || size == 0);
  ASSERT (src != NULL || size == 0);

  while (size-- > 0)
c0026b13:	85 f6                	test   %esi,%esi
c0026b15:	74 10                	je     c0026b27 <memcpy+0x22>
c0026b17:	ba 00 00 00 00       	mov    $0x0,%edx
    *dst++ = *src++;
c0026b1c:	8a 0c 13             	mov    (%ebx,%edx,1),%cl
c0026b1f:	88 0c 10             	mov    %cl,(%eax,%edx,1)
c0026b22:	42                   	inc    %edx
  while (size-- > 0)
c0026b23:	39 f2                	cmp    %esi,%edx
c0026b25:	75 f5                	jne    c0026b1c <memcpy+0x17>

  return dst_;
}
c0026b27:	5b                   	pop    %ebx
c0026b28:	5e                   	pop    %esi
c0026b29:	c3                   	ret    

c0026b2a <memmove>:

/* Copies SIZE bytes from SRC to DST, which are allowed to
   overlap.  Returns DST. */
void *
memmove (void *dst_, const void *src_, size_t size) 
{
c0026b2a:	57                   	push   %edi
c0026b2b:	56                   	push   %esi
c0026b2c:	53                   	push   %ebx
c0026b2d:	8b 4c 24 10          	mov    0x10(%esp),%ecx
c0026b31:	8b 5c 24 14          	mov    0x14(%esp),%ebx
c0026b35:	8b 74 24 18          	mov    0x18(%esp),%esi
  const unsigned char *src = src_;

  ASSERT (dst != NULL || size == 0);
  ASSERT (src != NULL || size == 0);

  if (dst < src) 
c0026b39:	39 d9                	cmp    %ebx,%ecx
c0026b3b:	73 1d                	jae    c0026b5a <memmove+0x30>
    {
      while (size-- > 0)
c0026b3d:	85 f6                	test   %esi,%esi
c0026b3f:	74 35                	je     c0026b76 <memmove+0x4c>
c0026b41:	b8 00 00 00 00       	mov    $0x0,%eax
        *dst++ = *src++;
c0026b46:	8a 14 03             	mov    (%ebx,%eax,1),%dl
c0026b49:	88 14 01             	mov    %dl,(%ecx,%eax,1)
c0026b4c:	40                   	inc    %eax
      while (size-- > 0)
c0026b4d:	39 f0                	cmp    %esi,%eax
c0026b4f:	75 f5                	jne    c0026b46 <memmove+0x1c>
c0026b51:	8d 3c 08             	lea    (%eax,%ecx,1),%edi
      while (size-- > 0)
        *--dst = *--src;
    }

  return dst;
}
c0026b54:	89 f8                	mov    %edi,%eax
c0026b56:	5b                   	pop    %ebx
c0026b57:	5e                   	pop    %esi
c0026b58:	5f                   	pop    %edi
c0026b59:	c3                   	ret    
      dst += size;
c0026b5a:	8d 3c 31             	lea    (%ecx,%esi,1),%edi
      while (size-- > 0)
c0026b5d:	8d 56 ff             	lea    -0x1(%esi),%edx
c0026b60:	85 f6                	test   %esi,%esi
c0026b62:	74 f0                	je     c0026b54 <memmove+0x2a>
c0026b64:	89 ce                	mov    %ecx,%esi
c0026b66:	89 f7                	mov    %esi,%edi
        *--dst = *--src;
c0026b68:	8a 04 13             	mov    (%ebx,%edx,1),%al
c0026b6b:	88 04 11             	mov    %al,(%ecx,%edx,1)
      while (size-- > 0)
c0026b6e:	4a                   	dec    %edx
c0026b6f:	83 fa ff             	cmp    $0xffffffff,%edx
c0026b72:	75 f2                	jne    c0026b66 <memmove+0x3c>
c0026b74:	eb de                	jmp    c0026b54 <memmove+0x2a>
      while (size-- > 0)
c0026b76:	89 cf                	mov    %ecx,%edi
c0026b78:	eb da                	jmp    c0026b54 <memmove+0x2a>

c0026b7a <memcmp>:
   at A and B.  Returns a positive value if the byte in A is
   greater, a negative value if the byte in B is greater, or zero
   if blocks A and B are equal. */
int
memcmp (const void *a_, const void *b_, size_t size) 
{
c0026b7a:	57                   	push   %edi
c0026b7b:	56                   	push   %esi
c0026b7c:	53                   	push   %ebx
c0026b7d:	8b 74 24 10          	mov    0x10(%esp),%esi
c0026b81:	8b 7c 24 14          	mov    0x14(%esp),%edi
c0026b85:	8b 5c 24 18          	mov    0x18(%esp),%ebx
  const unsigned char *b = b_;

  ASSERT (a != NULL || size == 0);
  ASSERT (b != NULL || size == 0);

  for (; size-- > 0; a++, b++)
c0026b89:	85 db                	test   %ebx,%ebx
c0026b8b:	74 30                	je     c0026bbd <memcmp+0x43>
    if (*a != *b)
c0026b8d:	8a 16                	mov    (%esi),%dl
c0026b8f:	8a 0f                	mov    (%edi),%cl
c0026b91:	38 ca                	cmp    %cl,%dl
c0026b93:	75 15                	jne    c0026baa <memcmp+0x30>
c0026b95:	b8 01 00 00 00       	mov    $0x1,%eax
  for (; size-- > 0; a++, b++)
c0026b9a:	39 d8                	cmp    %ebx,%eax
c0026b9c:	74 18                	je     c0026bb6 <memcmp+0x3c>
    if (*a != *b)
c0026b9e:	8a 14 06             	mov    (%esi,%eax,1),%dl
c0026ba1:	40                   	inc    %eax
c0026ba2:	8a 4c 07 ff          	mov    -0x1(%edi,%eax,1),%cl
c0026ba6:	38 ca                	cmp    %cl,%dl
c0026ba8:	74 f0                	je     c0026b9a <memcmp+0x20>
      return *a > *b ? +1 : -1;
c0026baa:	38 d1                	cmp    %dl,%cl
c0026bac:	19 c0                	sbb    %eax,%eax
c0026bae:	83 e0 02             	and    $0x2,%eax
c0026bb1:	48                   	dec    %eax
  return 0;
}
c0026bb2:	5b                   	pop    %ebx
c0026bb3:	5e                   	pop    %esi
c0026bb4:	5f                   	pop    %edi
c0026bb5:	c3                   	ret    
  return 0;
c0026bb6:	b8 00 00 00 00       	mov    $0x0,%eax
c0026bbb:	eb f5                	jmp    c0026bb2 <memcmp+0x38>
c0026bbd:	b8 00 00 00 00       	mov    $0x0,%eax
c0026bc2:	eb ee                	jmp    c0026bb2 <memcmp+0x38>

c0026bc4 <strcmp>:
   char) is greater, a negative value if the character in B (as
   an unsigned char) is greater, or zero if strings A and B are
   equal. */
int
strcmp (const char *a_, const char *b_) 
{
c0026bc4:	8b 4c 24 04          	mov    0x4(%esp),%ecx
c0026bc8:	8b 44 24 08          	mov    0x8(%esp),%eax
  const unsigned char *b = (const unsigned char *) b_;

  ASSERT (a != NULL);
  ASSERT (b != NULL);

  while (*a != '\0' && *a == *b) 
c0026bcc:	8a 11                	mov    (%ecx),%dl
c0026bce:	84 d2                	test   %dl,%dl
c0026bd0:	74 10                	je     c0026be2 <strcmp+0x1e>
c0026bd2:	3a 10                	cmp    (%eax),%dl
c0026bd4:	75 0c                	jne    c0026be2 <strcmp+0x1e>
    {
      a++;
c0026bd6:	41                   	inc    %ecx
      b++;
c0026bd7:	40                   	inc    %eax
  while (*a != '\0' && *a == *b) 
c0026bd8:	8a 11                	mov    (%ecx),%dl
c0026bda:	84 d2                	test   %dl,%dl
c0026bdc:	74 04                	je     c0026be2 <strcmp+0x1e>
c0026bde:	3a 10                	cmp    (%eax),%dl
c0026be0:	74 f4                	je     c0026bd6 <strcmp+0x12>
    }

  return *a < *b ? -1 : *a > *b;
c0026be2:	8a 00                	mov    (%eax),%al
c0026be4:	38 d0                	cmp    %dl,%al
c0026be6:	77 07                	ja     c0026bef <strcmp+0x2b>
c0026be8:	0f 92 c0             	setb   %al
c0026beb:	0f b6 c0             	movzbl %al,%eax
c0026bee:	c3                   	ret    
c0026bef:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
}
c0026bf4:	c3                   	ret    

c0026bf5 <memchr>:
/* Returns a pointer to the first occurrence of CH in the first
   SIZE bytes starting at BLOCK.  Returns a null pointer if CH
   does not occur in BLOCK. */
void *
memchr (const void *block_, int ch_, size_t size) 
{
c0026bf5:	53                   	push   %ebx
c0026bf6:	8b 44 24 08          	mov    0x8(%esp),%eax
c0026bfa:	8b 5c 24 0c          	mov    0xc(%esp),%ebx
c0026bfe:	8b 54 24 10          	mov    0x10(%esp),%edx
  const unsigned char *block = block_;
  unsigned char ch = ch_;

  ASSERT (block != NULL || size == 0);

  for (; size-- > 0; block++)
c0026c02:	85 d2                	test   %edx,%edx
c0026c04:	74 1a                	je     c0026c20 <memchr+0x2b>
c0026c06:	88 d9                	mov    %bl,%cl
    if (*block == ch)
c0026c08:	3a 18                	cmp    (%eax),%bl
c0026c0a:	74 12                	je     c0026c1e <memchr+0x29>
c0026c0c:	01 c2                	add    %eax,%edx
  for (; size-- > 0; block++)
c0026c0e:	40                   	inc    %eax
c0026c0f:	39 c2                	cmp    %eax,%edx
c0026c11:	74 06                	je     c0026c19 <memchr+0x24>
    if (*block == ch)
c0026c13:	3a 08                	cmp    (%eax),%cl
c0026c15:	75 f7                	jne    c0026c0e <memchr+0x19>
c0026c17:	eb 05                	jmp    c0026c1e <memchr+0x29>
      return (void *) block;

  return NULL;
c0026c19:	b8 00 00 00 00       	mov    $0x0,%eax
}
c0026c1e:	5b                   	pop    %ebx
c0026c1f:	c3                   	ret    
  return NULL;
c0026c20:	b8 00 00 00 00       	mov    $0x0,%eax
c0026c25:	eb f7                	jmp    c0026c1e <memchr+0x29>

c0026c27 <strchr>:
   null pointer if C does not appear in STRING.  If C == '\0'
   then returns a pointer to the null terminator at the end of
   STRING. */
char *
strchr (const char *string, int c_) 
{
c0026c27:	53                   	push   %ebx
c0026c28:	8b 44 24 08          	mov    0x8(%esp),%eax
c0026c2c:	8b 54 24 0c          	mov    0xc(%esp),%edx
  char c = c_;

  ASSERT (string != NULL);

  for (;;) 
    if (*string == c)
c0026c30:	8a 18                	mov    (%eax),%bl
c0026c32:	38 da                	cmp    %bl,%dl
c0026c34:	74 16                	je     c0026c4c <strchr+0x25>
c0026c36:	88 d1                	mov    %dl,%cl
      return (char *) string;
    else if (*string == '\0')
c0026c38:	84 db                	test   %bl,%bl
c0026c3a:	74 12                	je     c0026c4e <strchr+0x27>
      return NULL;
    else
      string++;
c0026c3c:	40                   	inc    %eax
    if (*string == c)
c0026c3d:	8a 10                	mov    (%eax),%dl
c0026c3f:	38 d1                	cmp    %dl,%cl
c0026c41:	74 09                	je     c0026c4c <strchr+0x25>
    else if (*string == '\0')
c0026c43:	84 d2                	test   %dl,%dl
c0026c45:	75 f5                	jne    c0026c3c <strchr+0x15>
      return NULL;
c0026c47:	b8 00 00 00 00       	mov    $0x0,%eax
}
c0026c4c:	5b                   	pop    %ebx
c0026c4d:	c3                   	ret    
      return NULL;
c0026c4e:	b8 00 00 00 00       	mov    $0x0,%eax
c0026c53:	eb f7                	jmp    c0026c4c <strchr+0x25>

c0026c55 <strcspn>:

/* Returns the length of the initial substring of STRING that
   consists of characters that are not in STOP. */
size_t
strcspn (const char *string, const char *stop) 
{
c0026c55:	57                   	push   %edi
c0026c56:	56                   	push   %esi
c0026c57:	53                   	push   %ebx
c0026c58:	8b 74 24 10          	mov    0x10(%esp),%esi
c0026c5c:	8b 7c 24 14          	mov    0x14(%esp),%edi
  size_t length;

  for (length = 0; string[length] != '\0'; length++)
c0026c60:	8a 06                	mov    (%esi),%al
c0026c62:	84 c0                	test   %al,%al
c0026c64:	74 24                	je     c0026c8a <strcspn+0x35>
c0026c66:	bb 00 00 00 00       	mov    $0x0,%ebx
    if (strchr (stop, string[length]) != NULL)
c0026c6b:	0f be c0             	movsbl %al,%eax
c0026c6e:	50                   	push   %eax
c0026c6f:	57                   	push   %edi
c0026c70:	e8 b2 ff ff ff       	call   c0026c27 <strchr>
c0026c75:	83 c4 08             	add    $0x8,%esp
c0026c78:	85 c0                	test   %eax,%eax
c0026c7a:	75 08                	jne    c0026c84 <strcspn+0x2f>
  for (length = 0; string[length] != '\0'; length++)
c0026c7c:	43                   	inc    %ebx
c0026c7d:	8a 04 1e             	mov    (%esi,%ebx,1),%al
c0026c80:	84 c0                	test   %al,%al
c0026c82:	75 e7                	jne    c0026c6b <strcspn+0x16>
      break;
  return length;
}
c0026c84:	89 d8                	mov    %ebx,%eax
c0026c86:	5b                   	pop    %ebx
c0026c87:	5e                   	pop    %esi
c0026c88:	5f                   	pop    %edi
c0026c89:	c3                   	ret    
  for (length = 0; string[length] != '\0'; length++)
c0026c8a:	bb 00 00 00 00       	mov    $0x0,%ebx
  return length;
c0026c8f:	eb f3                	jmp    c0026c84 <strcspn+0x2f>

c0026c91 <strpbrk>:
/* Returns a pointer to the first character in STRING that is
   also in STOP.  If no character in STRING is in STOP, returns a
   null pointer. */
char *
strpbrk (const char *string, const char *stop) 
{
c0026c91:	56                   	push   %esi
c0026c92:	53                   	push   %ebx
c0026c93:	8b 5c 24 0c          	mov    0xc(%esp),%ebx
c0026c97:	8b 74 24 10          	mov    0x10(%esp),%esi
  for (; *string != '\0'; string++)
c0026c9b:	8a 13                	mov    (%ebx),%dl
c0026c9d:	84 d2                	test   %dl,%dl
c0026c9f:	74 1a                	je     c0026cbb <strpbrk+0x2a>
    if (strchr (stop, *string) != NULL)
c0026ca1:	0f be d2             	movsbl %dl,%edx
c0026ca4:	52                   	push   %edx
c0026ca5:	56                   	push   %esi
c0026ca6:	e8 7c ff ff ff       	call   c0026c27 <strchr>
c0026cab:	83 c4 08             	add    $0x8,%esp
c0026cae:	85 c0                	test   %eax,%eax
c0026cb0:	75 10                	jne    c0026cc2 <strpbrk+0x31>
  for (; *string != '\0'; string++)
c0026cb2:	43                   	inc    %ebx
c0026cb3:	8a 13                	mov    (%ebx),%dl
c0026cb5:	84 d2                	test   %dl,%dl
c0026cb7:	75 e8                	jne    c0026ca1 <strpbrk+0x10>
c0026cb9:	eb 09                	jmp    c0026cc4 <strpbrk+0x33>
      return (char *) string;
  return NULL;
c0026cbb:	b8 00 00 00 00       	mov    $0x0,%eax
c0026cc0:	eb 02                	jmp    c0026cc4 <strpbrk+0x33>
c0026cc2:	89 d8                	mov    %ebx,%eax
}
c0026cc4:	5b                   	pop    %ebx
c0026cc5:	5e                   	pop    %esi
c0026cc6:	c3                   	ret    

c0026cc7 <strrchr>:

/* Returns a pointer to the last occurrence of C in STRING.
   Returns a null pointer if C does not occur in STRING. */
char *
strrchr (const char *string, int c_) 
{
c0026cc7:	53                   	push   %ebx
c0026cc8:	8b 54 24 08          	mov    0x8(%esp),%edx
  char c = c_;
c0026ccc:	8a 5c 24 0c          	mov    0xc(%esp),%bl
  const char *p = NULL;

  for (; *string != '\0'; string++)
c0026cd0:	8a 0a                	mov    (%edx),%cl
c0026cd2:	84 c9                	test   %cl,%cl
c0026cd4:	74 16                	je     c0026cec <strrchr+0x25>
c0026cd6:	b8 00 00 00 00       	mov    $0x0,%eax
c0026cdb:	eb 07                	jmp    c0026ce4 <strrchr+0x1d>
c0026cdd:	42                   	inc    %edx
c0026cde:	8a 0a                	mov    (%edx),%cl
c0026ce0:	84 c9                	test   %cl,%cl
c0026ce2:	74 0d                	je     c0026cf1 <strrchr+0x2a>
    if (*string == c)
c0026ce4:	38 cb                	cmp    %cl,%bl
c0026ce6:	75 f5                	jne    c0026cdd <strrchr+0x16>
c0026ce8:	89 d0                	mov    %edx,%eax
c0026cea:	eb f1                	jmp    c0026cdd <strrchr+0x16>
  const char *p = NULL;
c0026cec:	b8 00 00 00 00       	mov    $0x0,%eax
      p = string;
  return (char *) p;
}
c0026cf1:	5b                   	pop    %ebx
c0026cf2:	c3                   	ret    

c0026cf3 <strspn>:

/* Returns the length of the initial substring of STRING that
   consists of characters in SKIP. */
size_t
strspn (const char *string, const char *skip) 
{
c0026cf3:	57                   	push   %edi
c0026cf4:	56                   	push   %esi
c0026cf5:	53                   	push   %ebx
c0026cf6:	8b 74 24 10          	mov    0x10(%esp),%esi
c0026cfa:	8b 7c 24 14          	mov    0x14(%esp),%edi
  size_t length;
  
  for (length = 0; string[length] != '\0'; length++)
c0026cfe:	8a 06                	mov    (%esi),%al
c0026d00:	84 c0                	test   %al,%al
c0026d02:	74 24                	je     c0026d28 <strspn+0x35>
c0026d04:	bb 00 00 00 00       	mov    $0x0,%ebx
    if (strchr (skip, string[length]) == NULL)
c0026d09:	0f be c0             	movsbl %al,%eax
c0026d0c:	50                   	push   %eax
c0026d0d:	57                   	push   %edi
c0026d0e:	e8 14 ff ff ff       	call   c0026c27 <strchr>
c0026d13:	83 c4 08             	add    $0x8,%esp
c0026d16:	85 c0                	test   %eax,%eax
c0026d18:	74 08                	je     c0026d22 <strspn+0x2f>
  for (length = 0; string[length] != '\0'; length++)
c0026d1a:	43                   	inc    %ebx
c0026d1b:	8a 04 1e             	mov    (%esi,%ebx,1),%al
c0026d1e:	84 c0                	test   %al,%al
c0026d20:	75 e7                	jne    c0026d09 <strspn+0x16>
      break;
  return length;
}
c0026d22:	89 d8                	mov    %ebx,%eax
c0026d24:	5b                   	pop    %ebx
c0026d25:	5e                   	pop    %esi
c0026d26:	5f                   	pop    %edi
c0026d27:	c3                   	ret    
  for (length = 0; string[length] != '\0'; length++)
c0026d28:	bb 00 00 00 00       	mov    $0x0,%ebx
  return length;
c0026d2d:	eb f3                	jmp    c0026d22 <strspn+0x2f>

c0026d2f <strtok_r>:
     'to'
     'tokenize.'
*/
char *
strtok_r (char *s, const char *delimiters, char **save_ptr) 
{
c0026d2f:	55                   	push   %ebp
c0026d30:	57                   	push   %edi
c0026d31:	56                   	push   %esi
c0026d32:	53                   	push   %ebx
c0026d33:	83 ec 1c             	sub    $0x1c,%esp
c0026d36:	8b 74 24 30          	mov    0x30(%esp),%esi
c0026d3a:	8b 7c 24 34          	mov    0x34(%esp),%edi
  char *token;
  
  ASSERT (delimiters != NULL);
c0026d3e:	85 ff                	test   %edi,%edi
c0026d40:	74 2c                	je     c0026d6e <strtok_r+0x3f>
  ASSERT (save_ptr != NULL);
c0026d42:	83 7c 24 38 00       	cmpl   $0x0,0x38(%esp)
c0026d47:	74 46                	je     c0026d8f <strtok_r+0x60>

  /* If S is nonnull, start from it.
     If S is null, start from saved position. */
  if (s == NULL)
c0026d49:	85 f6                	test   %esi,%esi
c0026d4b:	74 63                	je     c0026db0 <strtok_r+0x81>
    s = *save_ptr;
  ASSERT (s != NULL);

  /* Skip any DELIMITERS at our current position. */
  while (strchr (delimiters, *s) != NULL) 
c0026d4d:	8a 1e                	mov    (%esi),%bl
c0026d4f:	83 ec 08             	sub    $0x8,%esp
c0026d52:	0f be c3             	movsbl %bl,%eax
c0026d55:	50                   	push   %eax
c0026d56:	57                   	push   %edi
c0026d57:	e8 cb fe ff ff       	call   c0026c27 <strchr>
c0026d5c:	83 c4 10             	add    $0x10,%esp
c0026d5f:	85 c0                	test   %eax,%eax
c0026d61:	0f 84 87 00 00 00    	je     c0026dee <strtok_r+0xbf>
    {
      /* strchr() will always return nonnull if we're searching
         for a null byte, because every string contains a null
         byte (at the end). */
      if (*s == '\0')
c0026d67:	84 db                	test   %bl,%bl
c0026d69:	74 70                	je     c0026ddb <strtok_r+0xac>
        {
          *save_ptr = s;
          return NULL;
        }

      s++;
c0026d6b:	46                   	inc    %esi
c0026d6c:	eb df                	jmp    c0026d4d <strtok_r+0x1e>
  ASSERT (delimiters != NULL);
c0026d6e:	83 ec 0c             	sub    $0xc,%esp
c0026d71:	68 8e e5 02 c0       	push   $0xc002e58e
c0026d76:	68 9f cd 02 c0       	push   $0xc002cd9f
c0026d7b:	68 70 c8 02 c0       	push   $0xc002c870
c0026d80:	68 ef 00 00 00       	push   $0xef
c0026d85:	68 a1 e5 02 c0       	push   $0xc002e5a1
c0026d8a:	e8 80 0a 00 00       	call   c002780f <debug_panic>
  ASSERT (save_ptr != NULL);
c0026d8f:	83 ec 0c             	sub    $0xc,%esp
c0026d92:	68 b4 e5 02 c0       	push   $0xc002e5b4
c0026d97:	68 9f cd 02 c0       	push   $0xc002cd9f
c0026d9c:	68 70 c8 02 c0       	push   $0xc002c870
c0026da1:	68 f0 00 00 00       	push   $0xf0
c0026da6:	68 a1 e5 02 c0       	push   $0xc002e5a1
c0026dab:	e8 5f 0a 00 00       	call   c002780f <debug_panic>
    s = *save_ptr;
c0026db0:	8b 44 24 38          	mov    0x38(%esp),%eax
c0026db4:	8b 30                	mov    (%eax),%esi
  ASSERT (s != NULL);
c0026db6:	85 f6                	test   %esi,%esi
c0026db8:	75 93                	jne    c0026d4d <strtok_r+0x1e>
c0026dba:	83 ec 0c             	sub    $0xc,%esp
c0026dbd:	68 97 e5 02 c0       	push   $0xc002e597
c0026dc2:	68 9f cd 02 c0       	push   $0xc002cd9f
c0026dc7:	68 70 c8 02 c0       	push   $0xc002c870
c0026dcc:	68 f6 00 00 00       	push   $0xf6
c0026dd1:	68 a1 e5 02 c0       	push   $0xc002e5a1
c0026dd6:	e8 34 0a 00 00       	call   c002780f <debug_panic>
          *save_ptr = s;
c0026ddb:	8b 44 24 38          	mov    0x38(%esp),%eax
c0026ddf:	89 30                	mov    %esi,(%eax)
          return NULL;
c0026de1:	b8 00 00 00 00       	mov    $0x0,%eax
      *save_ptr = s + 1;
    }
  else 
    *save_ptr = s;
  return token;
}
c0026de6:	83 c4 1c             	add    $0x1c,%esp
c0026de9:	5b                   	pop    %ebx
c0026dea:	5e                   	pop    %esi
c0026deb:	5f                   	pop    %edi
c0026dec:	5d                   	pop    %ebp
c0026ded:	c3                   	ret    
c0026dee:	89 f5                	mov    %esi,%ebp
c0026df0:	eb 04                	jmp    c0026df6 <strtok_r+0xc7>
    s++;
c0026df2:	8b 6c 24 0c          	mov    0xc(%esp),%ebp
c0026df6:	8d 45 01             	lea    0x1(%ebp),%eax
c0026df9:	89 44 24 0c          	mov    %eax,0xc(%esp)
  while (strchr (delimiters, *s) == NULL)
c0026dfd:	8a 5d 01             	mov    0x1(%ebp),%bl
c0026e00:	83 ec 08             	sub    $0x8,%esp
c0026e03:	0f be c3             	movsbl %bl,%eax
c0026e06:	50                   	push   %eax
c0026e07:	57                   	push   %edi
c0026e08:	e8 1a fe ff ff       	call   c0026c27 <strchr>
c0026e0d:	83 c4 10             	add    $0x10,%esp
c0026e10:	85 c0                	test   %eax,%eax
c0026e12:	74 de                	je     c0026df2 <strtok_r+0xc3>
  if (*s != '\0') 
c0026e14:	84 db                	test   %bl,%bl
c0026e16:	75 0e                	jne    c0026e26 <strtok_r+0xf7>
    *save_ptr = s;
c0026e18:	8b 44 24 38          	mov    0x38(%esp),%eax
c0026e1c:	8b 54 24 0c          	mov    0xc(%esp),%edx
c0026e20:	89 10                	mov    %edx,(%eax)
c0026e22:	89 f0                	mov    %esi,%eax
c0026e24:	eb c0                	jmp    c0026de6 <strtok_r+0xb7>
      *s = '\0';
c0026e26:	8b 44 24 0c          	mov    0xc(%esp),%eax
c0026e2a:	c6 00 00             	movb   $0x0,(%eax)
      *save_ptr = s + 1;
c0026e2d:	83 c5 02             	add    $0x2,%ebp
c0026e30:	8b 44 24 38          	mov    0x38(%esp),%eax
c0026e34:	89 28                	mov    %ebp,(%eax)
c0026e36:	89 f0                	mov    %esi,%eax
c0026e38:	eb ac                	jmp    c0026de6 <strtok_r+0xb7>

c0026e3a <memset>:

/* Sets the SIZE bytes in DST to VALUE. */
void *
memset (void *dst_, int value, size_t size) 
{
c0026e3a:	53                   	push   %ebx
c0026e3b:	8b 44 24 08          	mov    0x8(%esp),%eax
c0026e3f:	8b 5c 24 0c          	mov    0xc(%esp),%ebx
c0026e43:	8b 4c 24 10          	mov    0x10(%esp),%ecx
  unsigned char *dst = dst_;

  ASSERT (dst != NULL || size == 0);
  
  while (size-- > 0)
c0026e47:	85 c9                	test   %ecx,%ecx
c0026e49:	74 0c                	je     c0026e57 <memset+0x1d>
c0026e4b:	01 c1                	add    %eax,%ecx
c0026e4d:	89 c2                	mov    %eax,%edx
    *dst++ = value;
c0026e4f:	42                   	inc    %edx
c0026e50:	88 5a ff             	mov    %bl,-0x1(%edx)
  while (size-- > 0)
c0026e53:	39 d1                	cmp    %edx,%ecx
c0026e55:	75 f8                	jne    c0026e4f <memset+0x15>

  return dst_;
}
c0026e57:	5b                   	pop    %ebx
c0026e58:	c3                   	ret    

c0026e59 <strlen>:

/* Returns the length of STRING. */
size_t
strlen (const char *string) 
{
c0026e59:	8b 54 24 04          	mov    0x4(%esp),%edx
  const char *p;

  ASSERT (string != NULL);

  for (p = string; *p != '\0'; p++)
c0026e5d:	80 3a 00             	cmpb   $0x0,(%edx)
c0026e60:	74 0b                	je     c0026e6d <strlen+0x14>
c0026e62:	89 d0                	mov    %edx,%eax
c0026e64:	40                   	inc    %eax
c0026e65:	80 38 00             	cmpb   $0x0,(%eax)
c0026e68:	75 fa                	jne    c0026e64 <strlen+0xb>
    continue;
  return p - string;
c0026e6a:	29 d0                	sub    %edx,%eax
}
c0026e6c:	c3                   	ret    
  for (p = string; *p != '\0'; p++)
c0026e6d:	89 d0                	mov    %edx,%eax
c0026e6f:	eb f9                	jmp    c0026e6a <strlen+0x11>

c0026e71 <strstr>:
{
c0026e71:	55                   	push   %ebp
c0026e72:	57                   	push   %edi
c0026e73:	56                   	push   %esi
c0026e74:	53                   	push   %ebx
c0026e75:	83 ec 04             	sub    $0x4,%esp
c0026e78:	8b 6c 24 1c          	mov    0x1c(%esp),%ebp
  size_t haystack_len = strlen (haystack);
c0026e7c:	bb ff ff ff ff       	mov    $0xffffffff,%ebx
c0026e81:	b0 00                	mov    $0x0,%al
c0026e83:	89 d9                	mov    %ebx,%ecx
c0026e85:	8b 7c 24 18          	mov    0x18(%esp),%edi
c0026e89:	f2 ae                	repnz scas %es:(%edi),%al
c0026e8b:	f7 d1                	not    %ecx
c0026e8d:	8d 51 ff             	lea    -0x1(%ecx),%edx
  size_t needle_len = strlen (needle);
c0026e90:	89 d9                	mov    %ebx,%ecx
c0026e92:	89 ef                	mov    %ebp,%edi
c0026e94:	f2 ae                	repnz scas %es:(%edi),%al
c0026e96:	89 c8                	mov    %ecx,%eax
c0026e98:	f7 d0                	not    %eax
c0026e9a:	8d 78 ff             	lea    -0x1(%eax),%edi
  if (haystack_len >= needle_len) 
c0026e9d:	39 fa                	cmp    %edi,%edx
c0026e9f:	72 2c                	jb     c0026ecd <strstr+0x5c>
      for (i = 0; i <= haystack_len - needle_len; i++)
c0026ea1:	29 fa                	sub    %edi,%edx
c0026ea3:	89 14 24             	mov    %edx,(%esp)
c0026ea6:	bb 00 00 00 00       	mov    $0x0,%ebx
c0026eab:	89 de                	mov    %ebx,%esi
c0026ead:	03 74 24 18          	add    0x18(%esp),%esi
        if (!memcmp (haystack + i, needle, needle_len))
c0026eb1:	57                   	push   %edi
c0026eb2:	55                   	push   %ebp
c0026eb3:	56                   	push   %esi
c0026eb4:	e8 c1 fc ff ff       	call   c0026b7a <memcmp>
c0026eb9:	83 c4 0c             	add    $0xc,%esp
c0026ebc:	85 c0                	test   %eax,%eax
c0026ebe:	74 14                	je     c0026ed4 <strstr+0x63>
      for (i = 0; i <= haystack_len - needle_len; i++)
c0026ec0:	43                   	inc    %ebx
c0026ec1:	3b 1c 24             	cmp    (%esp),%ebx
c0026ec4:	76 e5                	jbe    c0026eab <strstr+0x3a>
  return NULL;
c0026ec6:	b8 00 00 00 00       	mov    $0x0,%eax
c0026ecb:	eb 09                	jmp    c0026ed6 <strstr+0x65>
c0026ecd:	b8 00 00 00 00       	mov    $0x0,%eax
c0026ed2:	eb 02                	jmp    c0026ed6 <strstr+0x65>
        if (!memcmp (haystack + i, needle, needle_len))
c0026ed4:	89 f0                	mov    %esi,%eax
}
c0026ed6:	83 c4 04             	add    $0x4,%esp
c0026ed9:	5b                   	pop    %ebx
c0026eda:	5e                   	pop    %esi
c0026edb:	5f                   	pop    %edi
c0026edc:	5d                   	pop    %ebp
c0026edd:	c3                   	ret    

c0026ede <strnlen>:

/* If STRING is less than MAXLEN characters in length, returns
   its actual length.  Otherwise, returns MAXLEN. */
size_t
strnlen (const char *string, size_t maxlen) 
{
c0026ede:	8b 4c 24 04          	mov    0x4(%esp),%ecx
c0026ee2:	8b 54 24 08          	mov    0x8(%esp),%edx
  size_t length;

  for (length = 0; string[length] != '\0' && length < maxlen; length++)
c0026ee6:	80 39 00             	cmpb   $0x0,(%ecx)
c0026ee9:	74 15                	je     c0026f00 <strnlen+0x22>
c0026eeb:	85 d2                	test   %edx,%edx
c0026eed:	74 17                	je     c0026f06 <strnlen+0x28>
c0026eef:	b8 00 00 00 00       	mov    $0x0,%eax
c0026ef4:	40                   	inc    %eax
c0026ef5:	80 3c 01 00          	cmpb   $0x0,(%ecx,%eax,1)
c0026ef9:	74 0d                	je     c0026f08 <strnlen+0x2a>
c0026efb:	39 c2                	cmp    %eax,%edx
c0026efd:	75 f5                	jne    c0026ef4 <strnlen+0x16>
c0026eff:	c3                   	ret    
c0026f00:	b8 00 00 00 00       	mov    $0x0,%eax
c0026f05:	c3                   	ret    
c0026f06:	89 d0                	mov    %edx,%eax
    continue;
  return length;
}
c0026f08:	c3                   	ret    

c0026f09 <strlcpy>:
   increasingly popular extension.  See
   http://www.courtesan.com/todd/papers/strlcpy.html for
   information on strlcpy(). */
size_t
strlcpy (char *dst, const char *src, size_t size) 
{
c0026f09:	55                   	push   %ebp
c0026f0a:	57                   	push   %edi
c0026f0b:	56                   	push   %esi
c0026f0c:	53                   	push   %ebx
c0026f0d:	83 ec 0c             	sub    $0xc,%esp
c0026f10:	8b 5c 24 20          	mov    0x20(%esp),%ebx
c0026f14:	8b 74 24 24          	mov    0x24(%esp),%esi
c0026f18:	8b 54 24 28          	mov    0x28(%esp),%edx
  size_t src_len;

  ASSERT (dst != NULL);
c0026f1c:	85 db                	test   %ebx,%ebx
c0026f1e:	74 33                	je     c0026f53 <strlcpy+0x4a>
  ASSERT (src != NULL);
c0026f20:	85 f6                	test   %esi,%esi
c0026f22:	74 50                	je     c0026f74 <strlcpy+0x6b>

  src_len = strlen (src);
c0026f24:	b0 00                	mov    $0x0,%al
c0026f26:	b9 ff ff ff ff       	mov    $0xffffffff,%ecx
c0026f2b:	89 f7                	mov    %esi,%edi
c0026f2d:	f2 ae                	repnz scas %es:(%edi),%al
c0026f2f:	89 c8                	mov    %ecx,%eax
c0026f31:	f7 d0                	not    %eax
c0026f33:	48                   	dec    %eax
  if (size > 0) 
c0026f34:	85 d2                	test   %edx,%edx
c0026f36:	74 13                	je     c0026f4b <strlcpy+0x42>
    {
      size_t dst_len = size - 1;
c0026f38:	4a                   	dec    %edx
c0026f39:	89 c5                	mov    %eax,%ebp
c0026f3b:	39 d0                	cmp    %edx,%eax
c0026f3d:	76 02                	jbe    c0026f41 <strlcpy+0x38>
c0026f3f:	89 d5                	mov    %edx,%ebp
      if (src_len < dst_len)
        dst_len = src_len;
      memcpy (dst, src, dst_len);
c0026f41:	89 df                	mov    %ebx,%edi
c0026f43:	89 e9                	mov    %ebp,%ecx
c0026f45:	f3 a4                	rep movsb %ds:(%esi),%es:(%edi)
      dst[dst_len] = '\0';
c0026f47:	c6 04 2b 00          	movb   $0x0,(%ebx,%ebp,1)
    }
  return src_len;
}
c0026f4b:	83 c4 0c             	add    $0xc,%esp
c0026f4e:	5b                   	pop    %ebx
c0026f4f:	5e                   	pop    %esi
c0026f50:	5f                   	pop    %edi
c0026f51:	5d                   	pop    %ebp
c0026f52:	c3                   	ret    
  ASSERT (dst != NULL);
c0026f53:	83 ec 0c             	sub    $0xc,%esp
c0026f56:	68 c5 e5 02 c0       	push   $0xc002e5c5
c0026f5b:	68 9f cd 02 c0       	push   $0xc002cd9f
c0026f60:	68 68 c8 02 c0       	push   $0xc002c868
c0026f65:	68 4a 01 00 00       	push   $0x14a
c0026f6a:	68 a1 e5 02 c0       	push   $0xc002e5a1
c0026f6f:	e8 9b 08 00 00       	call   c002780f <debug_panic>
  ASSERT (src != NULL);
c0026f74:	83 ec 0c             	sub    $0xc,%esp
c0026f77:	68 d1 e5 02 c0       	push   $0xc002e5d1
c0026f7c:	68 9f cd 02 c0       	push   $0xc002cd9f
c0026f81:	68 68 c8 02 c0       	push   $0xc002c868
c0026f86:	68 4b 01 00 00       	push   $0x14b
c0026f8b:	68 a1 e5 02 c0       	push   $0xc002e5a1
c0026f90:	e8 7a 08 00 00       	call   c002780f <debug_panic>

c0026f95 <strlcat>:
   increasingly popular extension.  See
   http://www.courtesan.com/todd/papers/strlcpy.html for
   information on strlcpy(). */
size_t
strlcat (char *dst, const char *src, size_t size) 
{
c0026f95:	55                   	push   %ebp
c0026f96:	57                   	push   %edi
c0026f97:	56                   	push   %esi
c0026f98:	53                   	push   %ebx
c0026f99:	83 ec 0c             	sub    $0xc,%esp
c0026f9c:	8b 74 24 24          	mov    0x24(%esp),%esi
c0026fa0:	8b 5c 24 28          	mov    0x28(%esp),%ebx
  size_t src_len, dst_len;

  ASSERT (dst != NULL);
c0026fa4:	83 7c 24 20 00       	cmpl   $0x0,0x20(%esp)
c0026fa9:	74 4f                	je     c0026ffa <strlcat+0x65>
  ASSERT (src != NULL);
c0026fab:	85 f6                	test   %esi,%esi
c0026fad:	74 6c                	je     c002701b <strlcat+0x86>

  src_len = strlen (src);
c0026faf:	bd ff ff ff ff       	mov    $0xffffffff,%ebp
c0026fb4:	b0 00                	mov    $0x0,%al
c0026fb6:	89 e9                	mov    %ebp,%ecx
c0026fb8:	89 f7                	mov    %esi,%edi
c0026fba:	f2 ae                	repnz scas %es:(%edi),%al
c0026fbc:	f7 d1                	not    %ecx
c0026fbe:	8d 51 ff             	lea    -0x1(%ecx),%edx
  dst_len = strlen (dst);
c0026fc1:	89 e9                	mov    %ebp,%ecx
c0026fc3:	8b 7c 24 20          	mov    0x20(%esp),%edi
c0026fc7:	f2 ae                	repnz scas %es:(%edi),%al
c0026fc9:	89 c8                	mov    %ecx,%eax
c0026fcb:	f7 d0                	not    %eax
c0026fcd:	48                   	dec    %eax
  if (size > 0 && dst_len < size) 
c0026fce:	85 db                	test   %ebx,%ebx
c0026fd0:	74 1e                	je     c0026ff0 <strlcat+0x5b>
c0026fd2:	39 d8                	cmp    %ebx,%eax
c0026fd4:	73 1a                	jae    c0026ff0 <strlcat+0x5b>
    {
      size_t copy_cnt = size - dst_len - 1;
c0026fd6:	8d 6b ff             	lea    -0x1(%ebx),%ebp
c0026fd9:	29 c5                	sub    %eax,%ebp
c0026fdb:	89 d1                	mov    %edx,%ecx
c0026fdd:	39 ea                	cmp    %ebp,%edx
c0026fdf:	76 02                	jbe    c0026fe3 <strlcat+0x4e>
c0026fe1:	89 e9                	mov    %ebp,%ecx
      if (src_len < copy_cnt)
        copy_cnt = src_len;
      memcpy (dst + dst_len, src, copy_cnt);
c0026fe3:	89 c3                	mov    %eax,%ebx
c0026fe5:	03 5c 24 20          	add    0x20(%esp),%ebx
c0026fe9:	89 df                	mov    %ebx,%edi
c0026feb:	f3 a4                	rep movsb %ds:(%esi),%es:(%edi)
      dst[dst_len + copy_cnt] = '\0';
c0026fed:	c6 07 00             	movb   $0x0,(%edi)
    }
  return src_len + dst_len;
c0026ff0:	01 d0                	add    %edx,%eax
}
c0026ff2:	83 c4 0c             	add    $0xc,%esp
c0026ff5:	5b                   	pop    %ebx
c0026ff6:	5e                   	pop    %esi
c0026ff7:	5f                   	pop    %edi
c0026ff8:	5d                   	pop    %ebp
c0026ff9:	c3                   	ret    
  ASSERT (dst != NULL);
c0026ffa:	83 ec 0c             	sub    $0xc,%esp
c0026ffd:	68 c5 e5 02 c0       	push   $0xc002e5c5
c0027002:	68 9f cd 02 c0       	push   $0xc002cd9f
c0027007:	68 60 c8 02 c0       	push   $0xc002c860
c002700c:	68 68 01 00 00       	push   $0x168
c0027011:	68 a1 e5 02 c0       	push   $0xc002e5a1
c0027016:	e8 f4 07 00 00       	call   c002780f <debug_panic>
  ASSERT (src != NULL);
c002701b:	83 ec 0c             	sub    $0xc,%esp
c002701e:	68 d1 e5 02 c0       	push   $0xc002e5d1
c0027023:	68 9f cd 02 c0       	push   $0xc002cd9f
c0027028:	68 60 c8 02 c0       	push   $0xc002c860
c002702d:	68 69 01 00 00       	push   $0x169
c0027032:	68 a1 e5 02 c0       	push   $0xc002e5a1
c0027037:	e8 d3 07 00 00       	call   c002780f <debug_panic>

c002703c <udiv64>:

/* Divides unsigned 64-bit N by unsigned 64-bit D and returns the
   quotient. */
static uint64_t
udiv64 (uint64_t n, uint64_t d)
{
c002703c:	55                   	push   %ebp
c002703d:	57                   	push   %edi
c002703e:	56                   	push   %esi
c002703f:	53                   	push   %ebx
c0027040:	83 ec 1c             	sub    $0x1c,%esp
c0027043:	89 04 24             	mov    %eax,(%esp)
c0027046:	89 54 24 04          	mov    %edx,0x4(%esp)
c002704a:	8b 74 24 30          	mov    0x30(%esp),%esi
c002704e:	8b 7c 24 34          	mov    0x34(%esp),%edi
  if ((d >> 32) == 0) 
c0027052:	85 ff                	test   %edi,%edi
c0027054:	74 2f                	je     c0027085 <udiv64+0x49>
c0027056:	89 fa                	mov    %edi,%edx
    }
  else 
    {
      /* Based on the algorithm and proof available from
         http://www.hackersdelight.org/revisions.pdf. */
      if (n < d)
c0027058:	8b 0c 24             	mov    (%esp),%ecx
c002705b:	8b 5c 24 04          	mov    0x4(%esp),%ebx
c002705f:	39 df                	cmp    %ebx,%edi
c0027061:	0f 87 43 01 00 00    	ja     c00271aa <udiv64+0x16e>
c0027067:	72 08                	jb     c0027071 <udiv64+0x35>
c0027069:	39 ce                	cmp    %ecx,%esi
c002706b:	0f 87 39 01 00 00    	ja     c00271aa <udiv64+0x16e>
        return 0;
      else 
        {
          uint32_t d1 = d >> 32;
c0027071:	89 d0                	mov    %edx,%eax
  if (x <= 0x0000FFFF)
c0027073:	81 fa ff ff 00 00    	cmp    $0xffff,%edx
c0027079:	77 56                	ja     c00270d1 <udiv64+0x95>
      x <<= 16; 
c002707b:	c1 e0 10             	shl    $0x10,%eax
      n += 16;
c002707e:	b9 10 00 00 00       	mov    $0x10,%ecx
c0027083:	eb 51                	jmp    c00270d6 <udiv64+0x9a>
      uint32_t n1 = n >> 32;
c0027085:	8b 44 24 04          	mov    0x4(%esp),%eax
      return divl (b * (n1 % d0) + n0, d0) + b * (n1 / d0); 
c0027089:	ba 00 00 00 00       	mov    $0x0,%edx
c002708e:	f7 f6                	div    %esi
c0027090:	89 d1                	mov    %edx,%ecx
c0027092:	89 c5                	mov    %eax,%ebp
c0027094:	b8 00 00 00 00       	mov    $0x0,%eax
c0027099:	89 ca                	mov    %ecx,%edx
c002709b:	8b 0c 24             	mov    (%esp),%ecx
c002709e:	bb 00 00 00 00       	mov    $0x0,%ebx
c00270a3:	01 c8                	add    %ecx,%eax
c00270a5:	11 da                	adc    %ebx,%edx
  asm ("divl %4"
c00270a7:	f7 f6                	div    %esi
      return divl (b * (n1 % d0) + n0, d0) + b * (n1 / d0); 
c00270a9:	be 00 00 00 00       	mov    $0x0,%esi
c00270ae:	89 c1                	mov    %eax,%ecx
c00270b0:	bb 00 00 00 00       	mov    $0x0,%ebx
c00270b5:	01 f1                	add    %esi,%ecx
c00270b7:	11 eb                	adc    %ebp,%ebx
c00270b9:	89 4c 24 08          	mov    %ecx,0x8(%esp)
c00270bd:	89 5c 24 0c          	mov    %ebx,0xc(%esp)
          int s = nlz (d1);
          uint64_t q = divl (n >> 1, (d << s) >> 32) >> (31 - s);
          return n - (q - 1) * d < d ? q - 1 : q; 
        }
    }
}
c00270c1:	8b 44 24 08          	mov    0x8(%esp),%eax
c00270c5:	8b 54 24 0c          	mov    0xc(%esp),%edx
c00270c9:	83 c4 1c             	add    $0x1c,%esp
c00270cc:	5b                   	pop    %ebx
c00270cd:	5e                   	pop    %esi
c00270ce:	5f                   	pop    %edi
c00270cf:	5d                   	pop    %ebp
c00270d0:	c3                   	ret    
  int n = 0;
c00270d1:	b9 00 00 00 00       	mov    $0x0,%ecx
  if (x <= 0x00FFFFFF)
c00270d6:	3d ff ff ff 00       	cmp    $0xffffff,%eax
c00270db:	77 06                	ja     c00270e3 <udiv64+0xa7>
      n += 8;
c00270dd:	83 c1 08             	add    $0x8,%ecx
      x <<= 8; 
c00270e0:	c1 e0 08             	shl    $0x8,%eax
  if (x <= 0x0FFFFFFF)
c00270e3:	3d ff ff ff 0f       	cmp    $0xfffffff,%eax
c00270e8:	77 06                	ja     c00270f0 <udiv64+0xb4>
      n += 4;
c00270ea:	83 c1 04             	add    $0x4,%ecx
      x <<= 4;
c00270ed:	c1 e0 04             	shl    $0x4,%eax
  if (x <= 0x3FFFFFFF)
c00270f0:	3d ff ff ff 3f       	cmp    $0x3fffffff,%eax
c00270f5:	77 06                	ja     c00270fd <udiv64+0xc1>
      n += 2;
c00270f7:	83 c1 02             	add    $0x2,%ecx
      x <<= 2; 
c00270fa:	c1 e0 02             	shl    $0x2,%eax
    n++;
c00270fd:	3d 00 00 00 80       	cmp    $0x80000000,%eax
c0027102:	83 d1 00             	adc    $0x0,%ecx
  uint32_t n1 = n >> 32;
c0027105:	8b 04 24             	mov    (%esp),%eax
c0027108:	8b 54 24 04          	mov    0x4(%esp),%edx
c002710c:	89 d3                	mov    %edx,%ebx
c002710e:	d1 eb                	shr    %ebx
          uint64_t q = divl (n >> 1, (d << s) >> 32) >> (31 - s);
c0027110:	0f ac d0 01          	shrd   $0x1,%edx,%eax
c0027114:	d1 ea                	shr    %edx
c0027116:	89 44 24 08          	mov    %eax,0x8(%esp)
c002711a:	89 54 24 0c          	mov    %edx,0xc(%esp)
c002711e:	89 f0                	mov    %esi,%eax
c0027120:	89 fa                	mov    %edi,%edx
c0027122:	0f a5 f2             	shld   %cl,%esi,%edx
c0027125:	d3 e0                	shl    %cl,%eax
c0027127:	f6 c1 20             	test   $0x20,%cl
c002712a:	74 02                	je     c002712e <udiv64+0xf2>
c002712c:	89 c2                	mov    %eax,%edx
c002712e:	89 54 24 14          	mov    %edx,0x14(%esp)
  asm ("divl %4"
c0027132:	89 da                	mov    %ebx,%edx
c0027134:	8b 44 24 08          	mov    0x8(%esp),%eax
c0027138:	f7 74 24 14          	divl   0x14(%esp)
          uint64_t q = divl (n >> 1, (d << s) >> 32) >> (31 - s);
c002713c:	ba 1f 00 00 00       	mov    $0x1f,%edx
c0027141:	29 ca                	sub    %ecx,%edx
c0027143:	89 d1                	mov    %edx,%ecx
c0027145:	d3 e8                	shr    %cl,%eax
c0027147:	b9 00 00 00 00       	mov    $0x0,%ecx
c002714c:	89 44 24 10          	mov    %eax,0x10(%esp)
c0027150:	89 4c 24 14          	mov    %ecx,0x14(%esp)
          return n - (q - 1) * d < d ? q - 1 : q; 
c0027154:	89 cb                	mov    %ecx,%ebx
c0027156:	89 c1                	mov    %eax,%ecx
c0027158:	83 c1 ff             	add    $0xffffffff,%ecx
c002715b:	83 d3 ff             	adc    $0xffffffff,%ebx
c002715e:	89 fd                	mov    %edi,%ebp
c0027160:	0f af e9             	imul   %ecx,%ebp
c0027163:	89 4c 24 08          	mov    %ecx,0x8(%esp)
c0027167:	89 5c 24 0c          	mov    %ebx,0xc(%esp)
c002716b:	0f af de             	imul   %esi,%ebx
c002716e:	01 dd                	add    %ebx,%ebp
c0027170:	89 f0                	mov    %esi,%eax
c0027172:	f7 64 24 08          	mull   0x8(%esp)
c0027176:	01 ea                	add    %ebp,%edx
c0027178:	8b 0c 24             	mov    (%esp),%ecx
c002717b:	8b 5c 24 04          	mov    0x4(%esp),%ebx
c002717f:	29 c1                	sub    %eax,%ecx
c0027181:	19 d3                	sbb    %edx,%ebx
c0027183:	39 df                	cmp    %ebx,%edi
c0027185:	0f 87 36 ff ff ff    	ja     c00270c1 <udiv64+0x85>
c002718b:	72 08                	jb     c0027195 <udiv64+0x159>
c002718d:	39 ce                	cmp    %ecx,%esi
c002718f:	0f 87 2c ff ff ff    	ja     c00270c1 <udiv64+0x85>
c0027195:	8b 44 24 10          	mov    0x10(%esp),%eax
c0027199:	8b 54 24 14          	mov    0x14(%esp),%edx
c002719d:	89 44 24 08          	mov    %eax,0x8(%esp)
c00271a1:	89 54 24 0c          	mov    %edx,0xc(%esp)
c00271a5:	e9 17 ff ff ff       	jmp    c00270c1 <udiv64+0x85>
        return 0;
c00271aa:	c7 44 24 08 00 00 00 	movl   $0x0,0x8(%esp)
c00271b1:	00 
c00271b2:	c7 44 24 0c 00 00 00 	movl   $0x0,0xc(%esp)
c00271b9:	00 
c00271ba:	e9 02 ff ff ff       	jmp    c00270c1 <udiv64+0x85>

c00271bf <sdiv64>:

/* Divides signed 64-bit N by signed 64-bit D and returns the
   quotient. */
static int64_t
sdiv64 (int64_t n, int64_t d)
{
c00271bf:	57                   	push   %edi
c00271c0:	56                   	push   %esi
c00271c1:	53                   	push   %ebx
c00271c2:	83 ec 08             	sub    $0x8,%esp
c00271c5:	89 04 24             	mov    %eax,(%esp)
c00271c8:	89 54 24 04          	mov    %edx,0x4(%esp)
c00271cc:	8b 74 24 18          	mov    0x18(%esp),%esi
c00271d0:	8b 7c 24 1c          	mov    0x1c(%esp),%edi
  uint64_t n_abs = n >= 0 ? (uint64_t) n : -(uint64_t) n;
c00271d4:	85 d2                	test   %edx,%edx
c00271d6:	78 32                	js     c002720a <sdiv64+0x4b>
c00271d8:	8b 04 24             	mov    (%esp),%eax
c00271db:	8b 54 24 04          	mov    0x4(%esp),%edx
  uint64_t d_abs = d >= 0 ? (uint64_t) d : -(uint64_t) d;
c00271df:	85 ff                	test   %edi,%edi
c00271e1:	78 30                	js     c0027213 <sdiv64+0x54>
c00271e3:	89 f1                	mov    %esi,%ecx
c00271e5:	89 fb                	mov    %edi,%ebx
  uint64_t q_abs = udiv64 (n_abs, d_abs);
c00271e7:	53                   	push   %ebx
c00271e8:	51                   	push   %ecx
c00271e9:	e8 4e fe ff ff       	call   c002703c <udiv64>
c00271ee:	83 c4 08             	add    $0x8,%esp
  return (n < 0) == (d < 0) ? (int64_t) q_abs : -(int64_t) q_abs;
c00271f1:	8b 4c 24 04          	mov    0x4(%esp),%ecx
c00271f5:	f7 d1                	not    %ecx
c00271f7:	c1 e9 1f             	shr    $0x1f,%ecx
c00271fa:	89 fb                	mov    %edi,%ebx
c00271fc:	c1 eb 1f             	shr    $0x1f,%ebx
c00271ff:	38 d9                	cmp    %bl,%cl
c0027201:	74 1d                	je     c0027220 <sdiv64+0x61>
}
c0027203:	83 c4 08             	add    $0x8,%esp
c0027206:	5b                   	pop    %ebx
c0027207:	5e                   	pop    %esi
c0027208:	5f                   	pop    %edi
c0027209:	c3                   	ret    
  uint64_t n_abs = n >= 0 ? (uint64_t) n : -(uint64_t) n;
c002720a:	f7 d8                	neg    %eax
c002720c:	83 d2 00             	adc    $0x0,%edx
c002720f:	f7 da                	neg    %edx
c0027211:	eb cc                	jmp    c00271df <sdiv64+0x20>
  uint64_t d_abs = d >= 0 ? (uint64_t) d : -(uint64_t) d;
c0027213:	89 f1                	mov    %esi,%ecx
c0027215:	89 fb                	mov    %edi,%ebx
c0027217:	f7 d9                	neg    %ecx
c0027219:	83 d3 00             	adc    $0x0,%ebx
c002721c:	f7 db                	neg    %ebx
c002721e:	eb c7                	jmp    c00271e7 <sdiv64+0x28>
  return (n < 0) == (d < 0) ? (int64_t) q_abs : -(int64_t) q_abs;
c0027220:	f7 d8                	neg    %eax
c0027222:	83 d2 00             	adc    $0x0,%edx
c0027225:	f7 da                	neg    %edx
c0027227:	eb da                	jmp    c0027203 <sdiv64+0x44>

c0027229 <__divdi3>:
unsigned long long __umoddi3 (unsigned long long n, unsigned long long d);

/* Signed 64-bit division. */
long long
__divdi3 (long long n, long long d) 
{
c0027229:	83 ec 04             	sub    $0x4,%esp
  return sdiv64 (n, d);
c002722c:	ff 74 24 14          	pushl  0x14(%esp)
c0027230:	ff 74 24 14          	pushl  0x14(%esp)
c0027234:	8b 44 24 10          	mov    0x10(%esp),%eax
c0027238:	8b 54 24 14          	mov    0x14(%esp),%edx
c002723c:	e8 7e ff ff ff       	call   c00271bf <sdiv64>
}
c0027241:	83 c4 0c             	add    $0xc,%esp
c0027244:	c3                   	ret    

c0027245 <__moddi3>:

/* Signed 64-bit remainder. */
long long
__moddi3 (long long n, long long d) 
{
c0027245:	57                   	push   %edi
c0027246:	56                   	push   %esi
c0027247:	53                   	push   %ebx
c0027248:	8b 5c 24 10          	mov    0x10(%esp),%ebx
c002724c:	8b 74 24 18          	mov    0x18(%esp),%esi
c0027250:	8b 7c 24 1c          	mov    0x1c(%esp),%edi
  return n - d * sdiv64 (n, d);
c0027254:	57                   	push   %edi
c0027255:	56                   	push   %esi
c0027256:	89 d8                	mov    %ebx,%eax
c0027258:	8b 54 24 1c          	mov    0x1c(%esp),%edx
c002725c:	e8 5e ff ff ff       	call   c00271bf <sdiv64>
c0027261:	83 c4 08             	add    $0x8,%esp
c0027264:	0f af c6             	imul   %esi,%eax
c0027267:	29 c3                	sub    %eax,%ebx
c0027269:	89 d8                	mov    %ebx,%eax
  return smod64 (n, d);
c002726b:	99                   	cltd   
}
c002726c:	5b                   	pop    %ebx
c002726d:	5e                   	pop    %esi
c002726e:	5f                   	pop    %edi
c002726f:	c3                   	ret    

c0027270 <__udivdi3>:

/* Unsigned 64-bit division. */
unsigned long long
__udivdi3 (unsigned long long n, unsigned long long d) 
{
c0027270:	83 ec 04             	sub    $0x4,%esp
  return udiv64 (n, d);
c0027273:	ff 74 24 14          	pushl  0x14(%esp)
c0027277:	ff 74 24 14          	pushl  0x14(%esp)
c002727b:	8b 44 24 10          	mov    0x10(%esp),%eax
c002727f:	8b 54 24 14          	mov    0x14(%esp),%edx
c0027283:	e8 b4 fd ff ff       	call   c002703c <udiv64>
}
c0027288:	83 c4 0c             	add    $0xc,%esp
c002728b:	c3                   	ret    

c002728c <__umoddi3>:

/* Unsigned 64-bit remainder. */
unsigned long long
__umoddi3 (unsigned long long n, unsigned long long d) 
{
c002728c:	57                   	push   %edi
c002728d:	56                   	push   %esi
c002728e:	53                   	push   %ebx
c002728f:	8b 5c 24 10          	mov    0x10(%esp),%ebx
c0027293:	8b 74 24 18          	mov    0x18(%esp),%esi
c0027297:	8b 7c 24 1c          	mov    0x1c(%esp),%edi
  return n - d * udiv64 (n, d);
c002729b:	57                   	push   %edi
c002729c:	56                   	push   %esi
c002729d:	89 d8                	mov    %ebx,%eax
c002729f:	8b 54 24 1c          	mov    0x1c(%esp),%edx
c00272a3:	e8 94 fd ff ff       	call   c002703c <udiv64>
c00272a8:	83 c4 08             	add    $0x8,%esp
c00272ab:	0f af c6             	imul   %esi,%eax
c00272ae:	29 c3                	sub    %eax,%ebx
c00272b0:	89 d8                	mov    %ebx,%eax
  return umod64 (n, d);
}
c00272b2:	ba 00 00 00 00       	mov    $0x0,%edx
c00272b7:	5b                   	pop    %ebx
c00272b8:	5e                   	pop    %esi
c00272b9:	5f                   	pop    %edi
c00272ba:	c3                   	ret    

c00272bb <parse_octal_field>:
static bool
parse_octal_field (const char *s, size_t size, unsigned long int *value)
{
  size_t ofs;

  *value = 0;
c00272bb:	c7 01 00 00 00 00    	movl   $0x0,(%ecx)
  for (ofs = 0; ofs < size; ofs++)
c00272c1:	85 d2                	test   %edx,%edx
c00272c3:	74 46                	je     c002730b <parse_octal_field+0x50>
{
c00272c5:	55                   	push   %ebp
c00272c6:	57                   	push   %edi
c00272c7:	56                   	push   %esi
c00272c8:	53                   	push   %ebx
c00272c9:	89 d5                	mov    %edx,%ebp
    {
      char c = s[ofs];
c00272cb:	8a 18                	mov    (%eax),%bl
      if (c >= '0' && c <= '7')
c00272cd:	8d 73 d0             	lea    -0x30(%ebx),%esi
c00272d0:	89 f2                	mov    %esi,%edx
  for (ofs = 0; ofs < size; ofs++)
c00272d2:	be 00 00 00 00       	mov    $0x0,%esi
      if (c >= '0' && c <= '7')
c00272d7:	80 fa 07             	cmp    $0x7,%dl
c00272da:	77 39                	ja     c0027315 <parse_octal_field+0x5a>
c00272dc:	bf 00 00 00 00       	mov    $0x0,%edi
c00272e1:	be 00 00 00 00       	mov    $0x0,%esi
          if (*value > ULONG_MAX / 8)
            {
              /* Overflow. */
              return false;
            }
          *value = c - '0' + *value * 8;
c00272e6:	0f be db             	movsbl %bl,%ebx
c00272e9:	8d 7c fb d0          	lea    -0x30(%ebx,%edi,8),%edi
c00272ed:	89 39                	mov    %edi,(%ecx)
  for (ofs = 0; ofs < size; ofs++)
c00272ef:	46                   	inc    %esi
c00272f0:	39 f5                	cmp    %esi,%ebp
c00272f2:	74 1a                	je     c002730e <parse_octal_field+0x53>
      char c = s[ofs];
c00272f4:	8a 1c 30             	mov    (%eax,%esi,1),%bl
      if (c >= '0' && c <= '7')
c00272f7:	8d 53 d0             	lea    -0x30(%ebx),%edx
c00272fa:	80 fa 07             	cmp    $0x7,%dl
c00272fd:	77 16                	ja     c0027315 <parse_octal_field+0x5a>
          if (*value > ULONG_MAX / 8)
c00272ff:	81 ff ff ff ff 1f    	cmp    $0x1fffffff,%edi
c0027305:	76 df                	jbe    c00272e6 <parse_octal_field+0x2b>
              return false;
c0027307:	b0 00                	mov    $0x0,%al
c0027309:	eb 05                	jmp    c0027310 <parse_octal_field+0x55>
          return false;
        }
    }

  /* Field did not end in space or null byte. */
  return false;
c002730b:	b0 00                	mov    $0x0,%al
c002730d:	c3                   	ret    
c002730e:	b0 00                	mov    $0x0,%al
}
c0027310:	5b                   	pop    %ebx
c0027311:	5e                   	pop    %esi
c0027312:	5f                   	pop    %edi
c0027313:	5d                   	pop    %ebp
c0027314:	c3                   	ret    
      else if (c == ' ' || c == '\0')
c0027315:	f6 c3 df             	test   $0xdf,%bl
c0027318:	75 07                	jne    c0027321 <parse_octal_field+0x66>
          return ofs > 0;
c002731a:	85 f6                	test   %esi,%esi
c002731c:	0f 95 c0             	setne  %al
c002731f:	eb ef                	jmp    c0027310 <parse_octal_field+0x55>
          return false;
c0027321:	b0 00                	mov    $0x0,%al
c0027323:	eb eb                	jmp    c0027310 <parse_octal_field+0x55>

c0027325 <strip_antisocial_prefixes>:
{
c0027325:	55                   	push   %ebp
c0027326:	57                   	push   %edi
c0027327:	56                   	push   %esi
c0027328:	53                   	push   %ebx
c0027329:	83 ec 0c             	sub    $0xc,%esp
c002732c:	89 c5                	mov    %eax,%ebp
  while (*file_name == '/'
c002732e:	eb 11                	jmp    c0027341 <strip_antisocial_prefixes+0x1c>
    file_name = strchr (file_name, '/') + 1;
c0027330:	83 ec 08             	sub    $0x8,%esp
c0027333:	6a 2f                	push   $0x2f
c0027335:	55                   	push   %ebp
c0027336:	e8 ec f8 ff ff       	call   c0026c27 <strchr>
c002733b:	83 c4 10             	add    $0x10,%esp
c002733e:	8d 68 01             	lea    0x1(%eax),%ebp
  while (*file_name == '/'
c0027341:	8a 5d 00             	mov    0x0(%ebp),%bl
c0027344:	80 fb 2f             	cmp    $0x2f,%bl
c0027347:	74 e7                	je     c0027330 <strip_antisocial_prefixes+0xb>
         || !memcmp (file_name, "./", 2)
c0027349:	83 ec 04             	sub    $0x4,%esp
c002734c:	6a 02                	push   $0x2
c002734e:	68 fd d9 02 c0       	push   $0xc002d9fd
c0027353:	55                   	push   %ebp
c0027354:	e8 21 f8 ff ff       	call   c0026b7a <memcmp>
c0027359:	83 c4 10             	add    $0x10,%esp
c002735c:	85 c0                	test   %eax,%eax
c002735e:	74 d0                	je     c0027330 <strip_antisocial_prefixes+0xb>
         || !memcmp (file_name, "../", 3))
c0027360:	83 ec 04             	sub    $0x4,%esp
c0027363:	6a 03                	push   $0x3
c0027365:	68 dd e5 02 c0       	push   $0xc002e5dd
c002736a:	55                   	push   %ebp
c002736b:	e8 0a f8 ff ff       	call   c0026b7a <memcmp>
c0027370:	83 c4 10             	add    $0x10,%esp
c0027373:	85 c0                	test   %eax,%eax
c0027375:	74 b9                	je     c0027330 <strip_antisocial_prefixes+0xb>
  return *file_name == '\0' || !strcmp (file_name, "..") ? "." : file_name;
c0027377:	84 db                	test   %bl,%bl
c0027379:	74 23                	je     c002739e <strip_antisocial_prefixes+0x79>
c002737b:	bf 82 df 02 c0       	mov    $0xc002df82,%edi
c0027380:	b9 03 00 00 00       	mov    $0x3,%ecx
c0027385:	89 ee                	mov    %ebp,%esi
c0027387:	f3 a6                	repz cmpsb %es:(%edi),%ds:(%esi)
c0027389:	0f 97 c2             	seta   %dl
c002738c:	0f 92 c0             	setb   %al
c002738f:	38 c2                	cmp    %al,%dl
c0027391:	75 07                	jne    c002739a <strip_antisocial_prefixes+0x75>
c0027393:	b8 83 df 02 c0       	mov    $0xc002df83,%eax
c0027398:	eb 09                	jmp    c00273a3 <strip_antisocial_prefixes+0x7e>
c002739a:	89 e8                	mov    %ebp,%eax
c002739c:	eb 05                	jmp    c00273a3 <strip_antisocial_prefixes+0x7e>
c002739e:	b8 83 df 02 c0       	mov    $0xc002df83,%eax
}
c00273a3:	83 c4 0c             	add    $0xc,%esp
c00273a6:	5b                   	pop    %ebx
c00273a7:	5e                   	pop    %esi
c00273a8:	5f                   	pop    %edi
c00273a9:	5d                   	pop    %ebp
c00273aa:	c3                   	ret    

c00273ab <ustar_make_header>:
{
c00273ab:	57                   	push   %edi
c00273ac:	56                   	push   %esi
c00273ad:	53                   	push   %ebx
c00273ae:	8b 44 24 10          	mov    0x10(%esp),%eax
c00273b2:	8b 5c 24 14          	mov    0x14(%esp),%ebx
c00273b6:	8b 74 24 1c          	mov    0x1c(%esp),%esi
  ASSERT (type == USTAR_REGULAR || type == USTAR_DIRECTORY);
c00273ba:	83 fb 30             	cmp    $0x30,%ebx
c00273bd:	0f 84 83 01 00 00    	je     c0027546 <ustar_make_header+0x19b>
c00273c3:	83 fb 35             	cmp    $0x35,%ebx
c00273c6:	0f 85 3e 01 00 00    	jne    c002750a <ustar_make_header+0x15f>
  file_name = strip_antisocial_prefixes (file_name);
c00273cc:	e8 54 ff ff ff       	call   c0027325 <strip_antisocial_prefixes>
c00273d1:	89 c2                	mov    %eax,%edx
  if (strlen (file_name) > 99)
c00273d3:	b0 00                	mov    $0x0,%al
c00273d5:	b9 ff ff ff ff       	mov    $0xffffffff,%ecx
c00273da:	89 d7                	mov    %edx,%edi
c00273dc:	f2 ae                	repnz scas %es:(%edi),%al
c00273de:	89 c8                	mov    %ecx,%eax
c00273e0:	f7 d0                	not    %eax
c00273e2:	48                   	dec    %eax
c00273e3:	83 f8 63             	cmp    $0x63,%eax
c00273e6:	0f 87 3c 01 00 00    	ja     c0027528 <ustar_make_header+0x17d>
  memset (h, 0, sizeof *h);
c00273ec:	b9 80 00 00 00       	mov    $0x80,%ecx
c00273f1:	b8 00 00 00 00       	mov    $0x0,%eax
c00273f6:	89 f7                	mov    %esi,%edi
c00273f8:	f3 ab                	rep stos %eax,%es:(%edi)
  strlcpy (h->name, file_name, sizeof h->name);
c00273fa:	83 ec 04             	sub    $0x4,%esp
c00273fd:	6a 64                	push   $0x64
c00273ff:	52                   	push   %edx
c0027400:	56                   	push   %esi
c0027401:	e8 03 fb ff ff       	call   c0026f09 <strlcpy>
c0027406:	83 c4 10             	add    $0x10,%esp
  snprintf (h->mode, sizeof h->mode, "%07o",
c0027409:	b8 ed 01 00 00       	mov    $0x1ed,%eax
c002740e:	50                   	push   %eax
c002740f:	68 0b e6 02 c0       	push   $0xc002e60b
c0027414:	6a 08                	push   $0x8
c0027416:	8d 46 64             	lea    0x64(%esi),%eax
c0027419:	50                   	push   %eax
c002741a:	e8 ce f0 ff ff       	call   c00264ed <snprintf>
  strlcpy (h->uid, "0000000", sizeof h->uid);
c002741f:	83 c4 0c             	add    $0xc,%esp
c0027422:	6a 08                	push   $0x8
c0027424:	68 10 e6 02 c0       	push   $0xc002e610
c0027429:	8d 46 6c             	lea    0x6c(%esi),%eax
c002742c:	50                   	push   %eax
c002742d:	e8 d7 fa ff ff       	call   c0026f09 <strlcpy>
  strlcpy (h->gid, "0000000", sizeof h->gid);
c0027432:	83 c4 0c             	add    $0xc,%esp
c0027435:	6a 08                	push   $0x8
c0027437:	68 10 e6 02 c0       	push   $0xc002e610
c002743c:	8d 46 74             	lea    0x74(%esi),%eax
c002743f:	50                   	push   %eax
c0027440:	e8 c4 fa ff ff       	call   c0026f09 <strlcpy>
  snprintf (h->size, sizeof h->size, "%011o", size);
c0027445:	ff 74 24 28          	pushl  0x28(%esp)
c0027449:	68 18 e6 02 c0       	push   $0xc002e618
c002744e:	6a 0c                	push   $0xc
c0027450:	8d 46 7c             	lea    0x7c(%esi),%eax
c0027453:	50                   	push   %eax
c0027454:	e8 94 f0 ff ff       	call   c00264ed <snprintf>
  snprintf (h->mtime, sizeof h->size, "%011o", 1136102400);
c0027459:	83 c4 20             	add    $0x20,%esp
c002745c:	68 00 8c b7 43       	push   $0x43b78c00
c0027461:	68 18 e6 02 c0       	push   $0xc002e618
c0027466:	6a 0c                	push   $0xc
c0027468:	8d 86 88 00 00 00    	lea    0x88(%esi),%eax
c002746e:	50                   	push   %eax
c002746f:	e8 79 f0 ff ff       	call   c00264ed <snprintf>
  h->typeflag = type;
c0027474:	88 9e 9c 00 00 00    	mov    %bl,0x9c(%esi)
  strlcpy (h->magic, "ustar", sizeof h->magic);
c002747a:	83 c4 0c             	add    $0xc,%esp
c002747d:	6a 06                	push   $0x6
c002747f:	68 1e e6 02 c0       	push   $0xc002e61e
c0027484:	8d 86 01 01 00 00    	lea    0x101(%esi),%eax
c002748a:	50                   	push   %eax
c002748b:	e8 79 fa ff ff       	call   c0026f09 <strlcpy>
  h->version[0] = h->version[1] = '0';
c0027490:	c6 86 08 01 00 00 30 	movb   $0x30,0x108(%esi)
c0027497:	c6 86 07 01 00 00 30 	movb   $0x30,0x107(%esi)
  strlcpy (h->gname, "root", sizeof h->gname);
c002749e:	83 c4 0c             	add    $0xc,%esp
c00274a1:	6a 20                	push   $0x20
c00274a3:	68 b4 db 02 c0       	push   $0xc002dbb4
c00274a8:	8d 86 29 01 00 00    	lea    0x129(%esi),%eax
c00274ae:	50                   	push   %eax
c00274af:	e8 55 fa ff ff       	call   c0026f09 <strlcpy>
  strlcpy (h->uname, "root", sizeof h->uname);
c00274b4:	83 c4 0c             	add    $0xc,%esp
c00274b7:	6a 20                	push   $0x20
c00274b9:	68 b4 db 02 c0       	push   $0xc002dbb4
c00274be:	8d 86 09 01 00 00    	lea    0x109(%esi),%eax
c00274c4:	50                   	push   %eax
c00274c5:	e8 3f fa ff ff       	call   c0026f09 <strlcpy>
c00274ca:	83 c4 10             	add    $0x10,%esp
c00274cd:	b8 6c ff ff ff       	mov    $0xffffff6c,%eax
  chksum = 0;
c00274d2:	b9 00 00 00 00       	mov    $0x0,%ecx
      chksum += in_chksum_field ? ' ' : header[i];
c00274d7:	b3 20                	mov    $0x20,%bl
c00274d9:	83 f8 07             	cmp    $0x7,%eax
c00274dc:	77 5f                	ja     c002753d <ustar_make_header+0x192>
c00274de:	88 da                	mov    %bl,%dl
c00274e0:	0f b6 d2             	movzbl %dl,%edx
c00274e3:	01 d1                	add    %edx,%ecx
c00274e5:	40                   	inc    %eax
  for (i = 0; i < USTAR_HEADER_SIZE; i++)
c00274e6:	3d 6c 01 00 00       	cmp    $0x16c,%eax
c00274eb:	75 ec                	jne    c00274d9 <ustar_make_header+0x12e>
  snprintf (h->chksum, sizeof h->chksum, "%07o", calculate_chksum (h));
c00274ed:	51                   	push   %ecx
c00274ee:	68 0b e6 02 c0       	push   $0xc002e60b
c00274f3:	6a 08                	push   $0x8
c00274f5:	81 c6 94 00 00 00    	add    $0x94,%esi
c00274fb:	56                   	push   %esi
c00274fc:	e8 ec ef ff ff       	call   c00264ed <snprintf>
  return true;
c0027501:	83 c4 10             	add    $0x10,%esp
c0027504:	b0 01                	mov    $0x1,%al
}
c0027506:	5b                   	pop    %ebx
c0027507:	5e                   	pop    %esi
c0027508:	5f                   	pop    %edi
c0027509:	c3                   	ret    
  ASSERT (type == USTAR_REGULAR || type == USTAR_DIRECTORY);
c002750a:	83 ec 0c             	sub    $0xc,%esp
c002750d:	68 c8 e6 02 c0       	push   $0xc002e6c8
c0027512:	68 9f cd 02 c0       	push   $0xc002cd9f
c0027517:	68 7c c8 02 c0       	push   $0xc002c87c
c002751c:	6a 59                	push   $0x59
c002751e:	68 e1 e5 02 c0       	push   $0xc002e5e1
c0027523:	e8 e7 02 00 00       	call   c002780f <debug_panic>
      printf ("%s: file name too long\n", file_name);
c0027528:	83 ec 08             	sub    $0x8,%esp
c002752b:	52                   	push   %edx
c002752c:	68 f3 e5 02 c0       	push   $0xc002e5f3
c0027531:	e8 2b e8 ff ff       	call   c0025d61 <printf>
      return false;
c0027536:	83 c4 10             	add    $0x10,%esp
c0027539:	b0 00                	mov    $0x0,%al
c002753b:	eb c9                	jmp    c0027506 <ustar_make_header+0x15b>
      chksum += in_chksum_field ? ' ' : header[i];
c002753d:	8a 94 06 94 00 00 00 	mov    0x94(%esi,%eax,1),%dl
c0027544:	eb 9a                	jmp    c00274e0 <ustar_make_header+0x135>
  file_name = strip_antisocial_prefixes (file_name);
c0027546:	e8 da fd ff ff       	call   c0027325 <strip_antisocial_prefixes>
c002754b:	89 c2                	mov    %eax,%edx
  if (strlen (file_name) > 99)
c002754d:	b0 00                	mov    $0x0,%al
c002754f:	b9 ff ff ff ff       	mov    $0xffffffff,%ecx
c0027554:	89 d7                	mov    %edx,%edi
c0027556:	f2 ae                	repnz scas %es:(%edi),%al
c0027558:	89 c8                	mov    %ecx,%eax
c002755a:	f7 d0                	not    %eax
c002755c:	48                   	dec    %eax
c002755d:	83 f8 63             	cmp    $0x63,%eax
c0027560:	77 c6                	ja     c0027528 <ustar_make_header+0x17d>
  memset (h, 0, sizeof *h);
c0027562:	b9 80 00 00 00       	mov    $0x80,%ecx
c0027567:	b8 00 00 00 00       	mov    $0x0,%eax
c002756c:	89 f7                	mov    %esi,%edi
c002756e:	f3 ab                	rep stos %eax,%es:(%edi)
  strlcpy (h->name, file_name, sizeof h->name);
c0027570:	83 ec 04             	sub    $0x4,%esp
c0027573:	6a 64                	push   $0x64
c0027575:	52                   	push   %edx
c0027576:	56                   	push   %esi
c0027577:	e8 8d f9 ff ff       	call   c0026f09 <strlcpy>
c002757c:	83 c4 10             	add    $0x10,%esp
  snprintf (h->mode, sizeof h->mode, "%07o",
c002757f:	b8 a4 01 00 00       	mov    $0x1a4,%eax
c0027584:	e9 85 fe ff ff       	jmp    c002740e <ustar_make_header+0x63>

c0027589 <ustar_parse_header>:
   and returns a null pointer.  On failure, returns a
   human-readable error message. */
const char *
ustar_parse_header (const char header[USTAR_HEADER_SIZE],
                    const char **file_name, enum ustar_type *type, int *size)
{
c0027589:	56                   	push   %esi
c002758a:	53                   	push   %ebx
c002758b:	83 ec 14             	sub    $0x14,%esp
c002758e:	8b 5c 24 20          	mov    0x20(%esp),%ebx
c0027592:	8d 93 00 02 00 00    	lea    0x200(%ebx),%edx
c0027598:	89 d8                	mov    %ebx,%eax
    if (*block++ != 0)
c002759a:	40                   	inc    %eax
c002759b:	80 78 ff 00          	cmpb   $0x0,-0x1(%eax)
c002759f:	0f 85 47 01 00 00    	jne    c00276ec <ustar_parse_header+0x163>
  while (cnt-- > 0)
c00275a5:	39 c2                	cmp    %eax,%edx
c00275a7:	75 f1                	jne    c002759a <ustar_parse_header+0x11>
  ASSERT (sizeof (struct ustar_header) == USTAR_HEADER_SIZE);

  /* Detect end of archive. */
  if (is_all_zeros (header, USTAR_HEADER_SIZE))
    {
      *file_name = NULL;
c00275a9:	8b 44 24 24          	mov    0x24(%esp),%eax
c00275ad:	c7 00 00 00 00 00    	movl   $0x0,(%eax)
      *type = USTAR_EOF;
c00275b3:	8b 44 24 28          	mov    0x28(%esp),%eax
c00275b7:	c7 00 ff ff ff ff    	movl   $0xffffffff,(%eax)
      *size = 0;
c00275bd:	8b 44 24 2c          	mov    0x2c(%esp),%eax
c00275c1:	c7 00 00 00 00 00    	movl   $0x0,(%eax)
      return NULL;
c00275c7:	b8 00 00 00 00       	mov    $0x0,%eax
  /* Success. */
  *file_name = strip_antisocial_prefixes (h->name);
  *type = h->typeflag;
  *size = size_ul;
  return NULL;
}
c00275cc:	83 c4 14             	add    $0x14,%esp
c00275cf:	5b                   	pop    %ebx
c00275d0:	5e                   	pop    %esi
c00275d1:	c3                   	ret    
  else if (h->version[0] != '0' || h->version[1] != '0')
c00275d2:	80 bb 08 01 00 00 30 	cmpb   $0x30,0x108(%ebx)
c00275d9:	74 07                	je     c00275e2 <ustar_parse_header+0x59>
    return "invalid ustar version";
c00275db:	b8 38 e6 02 c0       	mov    $0xc002e638,%eax
c00275e0:	eb ea                	jmp    c00275cc <ustar_parse_header+0x43>
  else if (!parse_octal_field (h->chksum, sizeof h->chksum, &chksum))
c00275e2:	8d 83 94 00 00 00    	lea    0x94(%ebx),%eax
c00275e8:	8d 4c 24 0c          	lea    0xc(%esp),%ecx
c00275ec:	ba 08 00 00 00       	mov    $0x8,%edx
c00275f1:	e8 c5 fc ff ff       	call   c00272bb <parse_octal_field>
c00275f6:	84 c0                	test   %al,%al
c00275f8:	0f 84 b2 00 00 00    	je     c00276b0 <ustar_parse_header+0x127>
c00275fe:	b8 6c ff ff ff       	mov    $0xffffff6c,%eax
c0027603:	b9 00 00 00 00       	mov    $0x0,%ecx
      chksum += in_chksum_field ? ' ' : header[i];
c0027608:	be 20 00 00 00       	mov    $0x20,%esi
c002760d:	83 f8 07             	cmp    $0x7,%eax
c0027610:	77 1c                	ja     c002762e <ustar_parse_header+0xa5>
c0027612:	89 f2                	mov    %esi,%edx
c0027614:	0f b6 d2             	movzbl %dl,%edx
c0027617:	01 d1                	add    %edx,%ecx
c0027619:	40                   	inc    %eax
  for (i = 0; i < USTAR_HEADER_SIZE; i++)
c002761a:	3d 6c 01 00 00       	cmp    $0x16c,%eax
c002761f:	75 ec                	jne    c002760d <ustar_parse_header+0x84>
  else if (chksum != calculate_chksum (h))
c0027621:	39 4c 24 0c          	cmp    %ecx,0xc(%esp)
c0027625:	74 10                	je     c0027637 <ustar_parse_header+0xae>
    return "checksum mismatch";
c0027627:	b8 63 e6 02 c0       	mov    $0xc002e663,%eax
c002762c:	eb 9e                	jmp    c00275cc <ustar_parse_header+0x43>
      chksum += in_chksum_field ? ' ' : header[i];
c002762e:	8a 94 03 94 00 00 00 	mov    0x94(%ebx,%eax,1),%dl
c0027635:	eb dd                	jmp    c0027614 <ustar_parse_header+0x8b>
  else if (h->name[sizeof h->name - 1] != '\0' || h->prefix[0] != '\0')
c0027637:	80 7b 63 00          	cmpb   $0x0,0x63(%ebx)
c002763b:	75 7d                	jne    c00276ba <ustar_parse_header+0x131>
c002763d:	80 bb 59 01 00 00 00 	cmpb   $0x0,0x159(%ebx)
c0027644:	75 7e                	jne    c00276c4 <ustar_parse_header+0x13b>
  else if (h->typeflag != USTAR_REGULAR && h->typeflag != USTAR_DIRECTORY)
c0027646:	8a 83 9c 00 00 00    	mov    0x9c(%ebx),%al
c002764c:	3c 30                	cmp    $0x30,%al
c002764e:	74 3a                	je     c002768a <ustar_parse_header+0x101>
c0027650:	3c 35                	cmp    $0x35,%al
c0027652:	75 7a                	jne    c00276ce <ustar_parse_header+0x145>
    size_ul = 0;
c0027654:	c7 44 24 08 00 00 00 	movl   $0x0,0x8(%esp)
c002765b:	00 
  *file_name = strip_antisocial_prefixes (h->name);
c002765c:	89 d8                	mov    %ebx,%eax
c002765e:	e8 c2 fc ff ff       	call   c0027325 <strip_antisocial_prefixes>
c0027663:	8b 74 24 24          	mov    0x24(%esp),%esi
c0027667:	89 06                	mov    %eax,(%esi)
  *type = h->typeflag;
c0027669:	0f be 83 9c 00 00 00 	movsbl 0x9c(%ebx),%eax
c0027670:	8b 74 24 28          	mov    0x28(%esp),%esi
c0027674:	89 06                	mov    %eax,(%esi)
  *size = size_ul;
c0027676:	8b 44 24 08          	mov    0x8(%esp),%eax
c002767a:	8b 74 24 2c          	mov    0x2c(%esp),%esi
c002767e:	89 06                	mov    %eax,(%esi)
  return NULL;
c0027680:	b8 00 00 00 00       	mov    $0x0,%eax
c0027685:	e9 42 ff ff ff       	jmp    c00275cc <ustar_parse_header+0x43>
      if (!parse_octal_field (h->size, sizeof h->size, &size_ul))
c002768a:	8d 43 7c             	lea    0x7c(%ebx),%eax
c002768d:	8d 4c 24 08          	lea    0x8(%esp),%ecx
c0027691:	ba 0c 00 00 00       	mov    $0xc,%edx
c0027696:	e8 20 fc ff ff       	call   c00272bb <parse_octal_field>
c002769b:	84 c0                	test   %al,%al
c002769d:	74 39                	je     c00276d8 <ustar_parse_header+0x14f>
      else if (size_ul > INT_MAX)
c002769f:	83 7c 24 08 00       	cmpl   $0x0,0x8(%esp)
c00276a4:	79 b6                	jns    c002765c <ustar_parse_header+0xd3>
        return "file too large";
c00276a6:	b8 b8 e6 02 c0       	mov    $0xc002e6b8,%eax
c00276ab:	e9 1c ff ff ff       	jmp    c00275cc <ustar_parse_header+0x43>
    return "corrupt chksum field";
c00276b0:	b8 4e e6 02 c0       	mov    $0xc002e64e,%eax
c00276b5:	e9 12 ff ff ff       	jmp    c00275cc <ustar_parse_header+0x43>
    return "file name too long";
c00276ba:	b8 75 e6 02 c0       	mov    $0xc002e675,%eax
c00276bf:	e9 08 ff ff ff       	jmp    c00275cc <ustar_parse_header+0x43>
c00276c4:	b8 75 e6 02 c0       	mov    $0xc002e675,%eax
c00276c9:	e9 fe fe ff ff       	jmp    c00275cc <ustar_parse_header+0x43>
    return "unimplemented file type";
c00276ce:	b8 88 e6 02 c0       	mov    $0xc002e688,%eax
c00276d3:	e9 f4 fe ff ff       	jmp    c00275cc <ustar_parse_header+0x43>
        return "corrupt file size field";
c00276d8:	b8 a0 e6 02 c0       	mov    $0xc002e6a0,%eax
c00276dd:	e9 ea fe ff ff       	jmp    c00275cc <ustar_parse_header+0x43>
    return "not a ustar archive";
c00276e2:	b8 24 e6 02 c0       	mov    $0xc002e624,%eax
c00276e7:	e9 e0 fe ff ff       	jmp    c00275cc <ustar_parse_header+0x43>
  if (memcmp (h->magic, "ustar", 6))
c00276ec:	83 ec 04             	sub    $0x4,%esp
c00276ef:	6a 06                	push   $0x6
c00276f1:	68 1e e6 02 c0       	push   $0xc002e61e
c00276f6:	8d 83 01 01 00 00    	lea    0x101(%ebx),%eax
c00276fc:	50                   	push   %eax
c00276fd:	e8 78 f4 ff ff       	call   c0026b7a <memcmp>
c0027702:	83 c4 10             	add    $0x10,%esp
c0027705:	85 c0                	test   %eax,%eax
c0027707:	75 d9                	jne    c00276e2 <ustar_parse_header+0x159>
  else if (h->version[0] != '0' || h->version[1] != '0')
c0027709:	80 bb 07 01 00 00 30 	cmpb   $0x30,0x107(%ebx)
c0027710:	0f 84 bc fe ff ff    	je     c00275d2 <ustar_parse_header+0x49>
    return "invalid ustar version";
c0027716:	b8 38 e6 02 c0       	mov    $0xc002e638,%eax
c002771b:	e9 ac fe ff ff       	jmp    c00275cc <ustar_parse_header+0x43>

c0027720 <print_stacktrace>:

/* Print call stack of a thread.
   The thread may be running, ready, or blocked. */
static void
print_stacktrace(struct thread *t, void *aux UNUSED)
{
c0027720:	55                   	push   %ebp
c0027721:	89 e5                	mov    %esp,%ebp
c0027723:	53                   	push   %ebx
c0027724:	83 ec 04             	sub    $0x4,%esp
c0027727:	8b 5d 08             	mov    0x8(%ebp),%ebx
  void *retaddr = NULL, **frame = NULL;
  const char *status = "UNKNOWN";

  switch (t->status) {
c002772a:	8b 43 04             	mov    0x4(%ebx),%eax
c002772d:	83 f8 01             	cmp    $0x1,%eax
c0027730:	0f 84 ab 00 00 00    	je     c00277e1 <print_stacktrace+0xc1>
c0027736:	83 f8 01             	cmp    $0x1,%eax
c0027739:	72 10                	jb     c002774b <print_stacktrace+0x2b>
c002773b:	83 f8 02             	cmp    $0x2,%eax
c002773e:	0f 84 a7 00 00 00    	je     c00277eb <print_stacktrace+0xcb>
  const char *status = "UNKNOWN";
c0027744:	b8 ff e6 02 c0       	mov    $0xc002e6ff,%eax
c0027749:	eb 05                	jmp    c0027750 <print_stacktrace+0x30>
    case THREAD_RUNNING:  
      status = "RUNNING";
c002774b:	b8 b3 d1 02 c0       	mov    $0xc002d1b3,%eax

    default:
      break;
  }

  printf ("Call stack of thread `%s' (status %s):", t->name, status);
c0027750:	83 ec 04             	sub    $0x4,%esp
c0027753:	50                   	push   %eax
c0027754:	8d 43 08             	lea    0x8(%ebx),%eax
c0027757:	50                   	push   %eax
c0027758:	68 24 e7 02 c0       	push   $0xc002e724
c002775d:	e8 ff e5 ff ff       	call   c0025d61 <printf>

  if (t == thread_current()) 
c0027762:	e8 e8 93 ff ff       	call   c0020b4f <thread_current>
c0027767:	83 c4 10             	add    $0x10,%esp
c002776a:	39 c3                	cmp    %eax,%ebx
c002776c:	0f 84 83 00 00 00    	je     c00277f5 <print_stacktrace+0xd5>
    {
      /* Retrieve the values of the base and instruction pointers
         as they were saved when this thread called switch_threads. */
      struct switch_threads_frame * saved_frame;

      saved_frame = (struct switch_threads_frame *)t->stack;
c0027772:	8b 53 18             	mov    0x18(%ebx),%edx
         list, but have never been scheduled.
         We can identify because their `stack' member either points 
         at the top of their kernel stack page, or the 
         switch_threads_frame's 'eip' member points at switch_entry.
         See also threads.c. */
      if (t->stack == (uint8_t *)t + PGSIZE || saved_frame->eip == switch_entry)
c0027775:	81 c3 00 10 00 00    	add    $0x1000,%ebx
c002777b:	39 da                	cmp    %ebx,%edx
c002777d:	74 7e                	je     c00277fd <print_stacktrace+0xdd>
c002777f:	8b 42 10             	mov    0x10(%edx),%eax
c0027782:	3d e3 10 02 c0       	cmp    $0xc00210e3,%eax
c0027787:	74 74                	je     c00277fd <print_stacktrace+0xdd>
        {
          printf (" thread was never scheduled.\n");
          return;
        }

      frame = (void **) saved_frame->ebp;
c0027789:	8b 5a 08             	mov    0x8(%edx),%ebx
      retaddr = (void *) saved_frame->eip;
    }

  printf (" %p", retaddr);
c002778c:	83 ec 08             	sub    $0x8,%esp
c002778f:	50                   	push   %eax
c0027790:	68 f5 e3 02 c0       	push   $0xc002e3f5
c0027795:	e8 c7 e5 ff ff       	call   c0025d61 <printf>
  for (; (uintptr_t) frame >= 0x1000 && frame[0] != NULL; frame = frame[0])
c002779a:	83 c4 10             	add    $0x10,%esp
c002779d:	81 fb ff 0f 00 00    	cmp    $0xfff,%ebx
c00277a3:	76 27                	jbe    c00277cc <print_stacktrace+0xac>
c00277a5:	83 3b 00             	cmpl   $0x0,(%ebx)
c00277a8:	74 22                	je     c00277cc <print_stacktrace+0xac>
    printf (" %p", frame[1]);
c00277aa:	83 ec 08             	sub    $0x8,%esp
c00277ad:	ff 73 04             	pushl  0x4(%ebx)
c00277b0:	68 f5 e3 02 c0       	push   $0xc002e3f5
c00277b5:	e8 a7 e5 ff ff       	call   c0025d61 <printf>
  for (; (uintptr_t) frame >= 0x1000 && frame[0] != NULL; frame = frame[0])
c00277ba:	8b 1b                	mov    (%ebx),%ebx
c00277bc:	83 c4 10             	add    $0x10,%esp
c00277bf:	81 fb ff 0f 00 00    	cmp    $0xfff,%ebx
c00277c5:	76 05                	jbe    c00277cc <print_stacktrace+0xac>
c00277c7:	83 3b 00             	cmpl   $0x0,(%ebx)
c00277ca:	75 de                	jne    c00277aa <print_stacktrace+0x8a>
  printf (".\n");
c00277cc:	83 ec 0c             	sub    $0xc,%esp
c00277cf:	68 83 df 02 c0       	push   $0xc002df83
c00277d4:	e8 84 1a 00 00       	call   c002925d <puts>
c00277d9:	83 c4 10             	add    $0x10,%esp
}
c00277dc:	8b 5d fc             	mov    -0x4(%ebp),%ebx
c00277df:	c9                   	leave  
c00277e0:	c3                   	ret    
      status = "READY";
c00277e1:	b8 f9 e6 02 c0       	mov    $0xc002e6f9,%eax
      break;
c00277e6:	e9 65 ff ff ff       	jmp    c0027750 <print_stacktrace+0x30>
      status = "BLOCKED";
c00277eb:	b8 57 d1 02 c0       	mov    $0xc002d157,%eax
      break;
c00277f0:	e9 5b ff ff ff       	jmp    c0027750 <print_stacktrace+0x30>
      frame = __builtin_frame_address (1);
c00277f5:	8b 5d 00             	mov    0x0(%ebp),%ebx
      retaddr = __builtin_return_address (0);
c00277f8:	8b 45 04             	mov    0x4(%ebp),%eax
c00277fb:	eb 8f                	jmp    c002778c <print_stacktrace+0x6c>
          printf (" thread was never scheduled.\n");
c00277fd:	83 ec 0c             	sub    $0xc,%esp
c0027800:	68 07 e7 02 c0       	push   $0xc002e707
c0027805:	e8 53 1a 00 00       	call   c002925d <puts>
          return;
c002780a:	83 c4 10             	add    $0x10,%esp
c002780d:	eb cd                	jmp    c00277dc <print_stacktrace+0xbc>

c002780f <debug_panic>:
{
c002780f:	57                   	push   %edi
c0027810:	56                   	push   %esi
c0027811:	53                   	push   %ebx
c0027812:	8b 5c 24 10          	mov    0x10(%esp),%ebx
c0027816:	8b 74 24 14          	mov    0x14(%esp),%esi
c002781a:	8b 7c 24 18          	mov    0x18(%esp),%edi
  intr_disable ();
c002781e:	e8 31 9a ff ff       	call   c0021254 <intr_disable>
  console_panic ();
c0027823:	e8 dc 19 00 00       	call   c0029204 <console_panic>
  level++;
c0027828:	a1 40 84 03 c0       	mov    0xc0038440,%eax
c002782d:	40                   	inc    %eax
c002782e:	a3 40 84 03 c0       	mov    %eax,0xc0038440
  if (level == 1) 
c0027833:	83 f8 01             	cmp    $0x1,%eax
c0027836:	74 11                	je     c0027849 <debug_panic+0x3a>
  else if (level == 2)
c0027838:	83 f8 02             	cmp    $0x2,%eax
c002783b:	74 40                	je     c002787d <debug_panic+0x6e>
  serial_flush ();
c002783d:	e8 d0 c4 ff ff       	call   c0023d12 <serial_flush>
  shutdown ();
c0027842:	e8 5c de ff ff       	call   c00256a3 <shutdown>
c0027847:	eb fe                	jmp    c0027847 <debug_panic+0x38>
      printf ("Kernel PANIC at %s:%d in %s(): ", file, line, function);
c0027849:	57                   	push   %edi
c002784a:	56                   	push   %esi
c002784b:	53                   	push   %ebx
c002784c:	68 4c e7 02 c0       	push   $0xc002e74c
c0027851:	e8 0b e5 ff ff       	call   c0025d61 <printf>
      va_start (args, message);
c0027856:	8d 44 24 30          	lea    0x30(%esp),%eax
      vprintf (message, args);
c002785a:	83 c4 08             	add    $0x8,%esp
c002785d:	50                   	push   %eax
c002785e:	ff 74 24 28          	pushl  0x28(%esp)
c0027862:	e8 c2 19 00 00       	call   c0029229 <vprintf>
      printf ("\n");
c0027867:	c7 04 24 0a 00 00 00 	movl   $0xa,(%esp)
c002786e:	e8 56 1a 00 00       	call   c00292c9 <putchar>
      debug_backtrace ();
c0027873:	e8 e6 de ff ff       	call   c002575e <debug_backtrace>
c0027878:	83 c4 10             	add    $0x10,%esp
c002787b:	eb c0                	jmp    c002783d <debug_panic+0x2e>
    printf ("Kernel PANIC recursion at %s:%d in %s().\n",
c002787d:	57                   	push   %edi
c002787e:	56                   	push   %esi
c002787f:	53                   	push   %ebx
c0027880:	68 6c e7 02 c0       	push   $0xc002e76c
c0027885:	e8 d7 e4 ff ff       	call   c0025d61 <printf>
c002788a:	83 c4 10             	add    $0x10,%esp
c002788d:	eb ae                	jmp    c002783d <debug_panic+0x2e>

c002788f <debug_backtrace_all>:

/* Prints call stack of all threads. */
void
debug_backtrace_all (void)
{
c002788f:	53                   	push   %ebx
c0027890:	83 ec 08             	sub    $0x8,%esp
  enum intr_level oldlevel = intr_disable ();
c0027893:	e8 bc 99 ff ff       	call   c0021254 <intr_disable>
c0027898:	89 c3                	mov    %eax,%ebx

  thread_foreach (print_stacktrace, 0);
c002789a:	83 ec 08             	sub    $0x8,%esp
c002789d:	6a 00                	push   $0x0
c002789f:	68 20 77 02 c0       	push   $0xc0027720
c00278a4:	e8 f2 93 ff ff       	call   c0020c9b <thread_foreach>
  intr_set_level (oldlevel);
c00278a9:	89 1c 24             	mov    %ebx,(%esp)
c00278ac:	e8 aa 99 ff ff       	call   c002125b <intr_set_level>
}
c00278b1:	83 c4 18             	add    $0x18,%esp
c00278b4:	5b                   	pop    %ebx
c00278b5:	c3                   	ret    

c00278b6 <list_init>:
}

/* Initializes LIST as an empty list. */
void
list_init (struct list *list)
{
c00278b6:	83 ec 0c             	sub    $0xc,%esp
c00278b9:	8b 44 24 10          	mov    0x10(%esp),%eax
  ASSERT (list != NULL);
c00278bd:	85 c0                	test   %eax,%eax
c00278bf:	74 1a                	je     c00278db <list_init+0x25>
  list->head.prev = NULL;
c00278c1:	c7 00 00 00 00 00    	movl   $0x0,(%eax)
  list->head.next = &list->tail;
c00278c7:	8d 50 08             	lea    0x8(%eax),%edx
c00278ca:	89 50 04             	mov    %edx,0x4(%eax)
  list->tail.prev = &list->head;
c00278cd:	89 40 08             	mov    %eax,0x8(%eax)
  list->tail.next = NULL;
c00278d0:	c7 40 0c 00 00 00 00 	movl   $0x0,0xc(%eax)
}
c00278d7:	83 c4 0c             	add    $0xc,%esp
c00278da:	c3                   	ret    
  ASSERT (list != NULL);
c00278db:	83 ec 0c             	sub    $0xc,%esp
c00278de:	68 96 e7 02 c0       	push   $0xc002e796
c00278e3:	68 9f cd 02 c0       	push   $0xc002cd9f
c00278e8:	68 78 c9 02 c0       	push   $0xc002c978
c00278ed:	6a 3f                	push   $0x3f
c00278ef:	68 a3 e7 02 c0       	push   $0xc002e7a3
c00278f4:	e8 16 ff ff ff       	call   c002780f <debug_panic>

c00278f9 <list_begin>:

/* Returns the beginning of LIST.  */
struct list_elem *
list_begin (struct list *list)
{
c00278f9:	83 ec 0c             	sub    $0xc,%esp
c00278fc:	8b 44 24 10          	mov    0x10(%esp),%eax
  ASSERT (list != NULL);
c0027900:	85 c0                	test   %eax,%eax
c0027902:	74 07                	je     c002790b <list_begin+0x12>
  return list->head.next;
c0027904:	8b 40 04             	mov    0x4(%eax),%eax
}
c0027907:	83 c4 0c             	add    $0xc,%esp
c002790a:	c3                   	ret    
  ASSERT (list != NULL);
c002790b:	83 ec 0c             	sub    $0xc,%esp
c002790e:	68 96 e7 02 c0       	push   $0xc002e796
c0027913:	68 9f cd 02 c0       	push   $0xc002cd9f
c0027918:	68 6c c9 02 c0       	push   $0xc002c96c
c002791d:	6a 4a                	push   $0x4a
c002791f:	68 a3 e7 02 c0       	push   $0xc002e7a3
c0027924:	e8 e6 fe ff ff       	call   c002780f <debug_panic>

c0027929 <list_next>:
/* Returns the element after ELEM in its list.  If ELEM is the
   last element in its list, returns the list tail.  Results are
   undefined if ELEM is itself a list tail. */
struct list_elem *
list_next (struct list_elem *elem)
{
c0027929:	83 ec 0c             	sub    $0xc,%esp
c002792c:	8b 44 24 10          	mov    0x10(%esp),%eax
  return elem != NULL && elem->prev == NULL && elem->next != NULL;
c0027930:	85 c0                	test   %eax,%eax
c0027932:	74 1f                	je     c0027953 <list_next+0x2a>
c0027934:	83 38 00             	cmpl   $0x0,(%eax)
c0027937:	74 12                	je     c002794b <list_next+0x22>
  return elem != NULL && elem->prev != NULL && elem->next != NULL;
c0027939:	83 38 00             	cmpl   $0x0,(%eax)
c002793c:	74 15                	je     c0027953 <list_next+0x2a>
c002793e:	83 78 04 00          	cmpl   $0x0,0x4(%eax)
c0027942:	74 0f                	je     c0027953 <list_next+0x2a>
  ASSERT (is_head (elem) || is_interior (elem));
  return elem->next;
c0027944:	8b 40 04             	mov    0x4(%eax),%eax
}
c0027947:	83 c4 0c             	add    $0xc,%esp
c002794a:	c3                   	ret    
  return elem != NULL && elem->prev == NULL && elem->next != NULL;
c002794b:	83 78 04 00          	cmpl   $0x0,0x4(%eax)
c002794f:	75 f3                	jne    c0027944 <list_next+0x1b>
c0027951:	eb e6                	jmp    c0027939 <list_next+0x10>
  ASSERT (is_head (elem) || is_interior (elem));
c0027953:	83 ec 0c             	sub    $0xc,%esp
c0027956:	68 58 e8 02 c0       	push   $0xc002e858
c002795b:	68 9f cd 02 c0       	push   $0xc002cd9f
c0027960:	68 60 c9 02 c0       	push   $0xc002c960
c0027965:	6a 54                	push   $0x54
c0027967:	68 a3 e7 02 c0       	push   $0xc002e7a3
c002796c:	e8 9e fe ff ff       	call   c002780f <debug_panic>

c0027971 <list_end>:
   list_end() is often used in iterating through a list from
   front to back.  See the big comment at the top of list.h for
   an example. */
struct list_elem *
list_end (struct list *list)
{
c0027971:	83 ec 0c             	sub    $0xc,%esp
c0027974:	8b 44 24 10          	mov    0x10(%esp),%eax
  ASSERT (list != NULL);
c0027978:	85 c0                	test   %eax,%eax
c002797a:	74 07                	je     c0027983 <list_end+0x12>
  return &list->tail;
c002797c:	83 c0 08             	add    $0x8,%eax
}
c002797f:	83 c4 0c             	add    $0xc,%esp
c0027982:	c3                   	ret    
  ASSERT (list != NULL);
c0027983:	83 ec 0c             	sub    $0xc,%esp
c0027986:	68 96 e7 02 c0       	push   $0xc002e796
c002798b:	68 9f cd 02 c0       	push   $0xc002cd9f
c0027990:	68 54 c9 02 c0       	push   $0xc002c954
c0027995:	6a 60                	push   $0x60
c0027997:	68 a3 e7 02 c0       	push   $0xc002e7a3
c002799c:	e8 6e fe ff ff       	call   c002780f <debug_panic>

c00279a1 <list_rbegin>:

/* Returns the LIST's reverse beginning, for iterating through
   LIST in reverse order, from back to front. */
struct list_elem *
list_rbegin (struct list *list) 
{
c00279a1:	83 ec 0c             	sub    $0xc,%esp
c00279a4:	8b 44 24 10          	mov    0x10(%esp),%eax
  ASSERT (list != NULL);
c00279a8:	85 c0                	test   %eax,%eax
c00279aa:	74 07                	je     c00279b3 <list_rbegin+0x12>
  return list->tail.prev;
c00279ac:	8b 40 08             	mov    0x8(%eax),%eax
}
c00279af:	83 c4 0c             	add    $0xc,%esp
c00279b2:	c3                   	ret    
  ASSERT (list != NULL);
c00279b3:	83 ec 0c             	sub    $0xc,%esp
c00279b6:	68 96 e7 02 c0       	push   $0xc002e796
c00279bb:	68 9f cd 02 c0       	push   $0xc002cd9f
c00279c0:	68 48 c9 02 c0       	push   $0xc002c948
c00279c5:	6a 69                	push   $0x69
c00279c7:	68 a3 e7 02 c0       	push   $0xc002e7a3
c00279cc:	e8 3e fe ff ff       	call   c002780f <debug_panic>

c00279d1 <list_prev>:
/* Returns the element before ELEM in its list.  If ELEM is the
   first element in its list, returns the list head.  Results are
   undefined if ELEM is itself a list head. */
struct list_elem *
list_prev (struct list_elem *elem)
{
c00279d1:	83 ec 0c             	sub    $0xc,%esp
c00279d4:	8b 44 24 10          	mov    0x10(%esp),%eax
  return elem != NULL && elem->prev != NULL && elem->next != NULL;
c00279d8:	85 c0                	test   %eax,%eax
c00279da:	74 1c                	je     c00279f8 <list_prev+0x27>
c00279dc:	83 38 00             	cmpl   $0x0,(%eax)
c00279df:	74 0c                	je     c00279ed <list_prev+0x1c>
c00279e1:	83 78 04 00          	cmpl   $0x0,0x4(%eax)
c00279e5:	74 06                	je     c00279ed <list_prev+0x1c>
  ASSERT (is_interior (elem) || is_tail (elem));
  return elem->prev;
c00279e7:	8b 00                	mov    (%eax),%eax
}
c00279e9:	83 c4 0c             	add    $0xc,%esp
c00279ec:	c3                   	ret    
  return elem != NULL && elem->prev != NULL && elem->next == NULL;
c00279ed:	83 38 00             	cmpl   $0x0,(%eax)
c00279f0:	74 06                	je     c00279f8 <list_prev+0x27>
c00279f2:	83 78 04 00          	cmpl   $0x0,0x4(%eax)
c00279f6:	74 ef                	je     c00279e7 <list_prev+0x16>
  ASSERT (is_interior (elem) || is_tail (elem));
c00279f8:	83 ec 0c             	sub    $0xc,%esp
c00279fb:	68 80 e8 02 c0       	push   $0xc002e880
c0027a00:	68 9f cd 02 c0       	push   $0xc002cd9f
c0027a05:	68 3c c9 02 c0       	push   $0xc002c93c
c0027a0a:	6a 73                	push   $0x73
c0027a0c:	68 a3 e7 02 c0       	push   $0xc002e7a3
c0027a11:	e8 f9 fd ff ff       	call   c002780f <debug_panic>

c0027a16 <find_end_of_run>:
   run.
   A through B (exclusive) must form a non-empty range. */
static struct list_elem *
find_end_of_run (struct list_elem *a, struct list_elem *b,
                 list_less_func *less, void *aux)
{
c0027a16:	55                   	push   %ebp
c0027a17:	57                   	push   %edi
c0027a18:	56                   	push   %esi
c0027a19:	53                   	push   %ebx
c0027a1a:	83 ec 0c             	sub    $0xc,%esp
c0027a1d:	8b 6c 24 20          	mov    0x20(%esp),%ebp
  ASSERT (a != NULL);
c0027a21:	85 c0                	test   %eax,%eax
c0027a23:	74 50                	je     c0027a75 <find_end_of_run+0x5f>
c0027a25:	89 c3                	mov    %eax,%ebx
c0027a27:	89 d6                	mov    %edx,%esi
c0027a29:	89 cf                	mov    %ecx,%edi
  ASSERT (b != NULL);
c0027a2b:	85 d2                	test   %edx,%edx
c0027a2d:	74 67                	je     c0027a96 <find_end_of_run+0x80>
  ASSERT (less != NULL);
c0027a2f:	85 c9                	test   %ecx,%ecx
c0027a31:	0f 84 80 00 00 00    	je     c0027ab7 <find_end_of_run+0xa1>
  ASSERT (a != b);
c0027a37:	39 d0                	cmp    %edx,%eax
c0027a39:	0f 84 99 00 00 00    	je     c0027ad8 <find_end_of_run+0xc2>
  
  do 
    {
      a = list_next (a);
c0027a3f:	83 ec 0c             	sub    $0xc,%esp
c0027a42:	53                   	push   %ebx
c0027a43:	e8 e1 fe ff ff       	call   c0027929 <list_next>
c0027a48:	83 c4 10             	add    $0x10,%esp
c0027a4b:	89 c3                	mov    %eax,%ebx
    }
  while (a != b && !less (a, list_prev (a), aux));
c0027a4d:	39 c6                	cmp    %eax,%esi
c0027a4f:	74 1a                	je     c0027a6b <find_end_of_run+0x55>
c0027a51:	83 ec 0c             	sub    $0xc,%esp
c0027a54:	50                   	push   %eax
c0027a55:	e8 77 ff ff ff       	call   c00279d1 <list_prev>
c0027a5a:	83 c4 0c             	add    $0xc,%esp
c0027a5d:	55                   	push   %ebp
c0027a5e:	50                   	push   %eax
c0027a5f:	53                   	push   %ebx
c0027a60:	ff d7                	call   *%edi
c0027a62:	83 c4 10             	add    $0x10,%esp
c0027a65:	84 c0                	test   %al,%al
c0027a67:	74 d6                	je     c0027a3f <find_end_of_run+0x29>
      a = list_next (a);
c0027a69:	89 de                	mov    %ebx,%esi
  return a;
}
c0027a6b:	89 f0                	mov    %esi,%eax
c0027a6d:	83 c4 0c             	add    $0xc,%esp
c0027a70:	5b                   	pop    %ebx
c0027a71:	5e                   	pop    %esi
c0027a72:	5f                   	pop    %edi
c0027a73:	5d                   	pop    %ebp
c0027a74:	c3                   	ret    
  ASSERT (a != NULL);
c0027a75:	83 ec 0c             	sub    $0xc,%esp
c0027a78:	68 19 d6 02 c0       	push   $0xc002d619
c0027a7d:	68 9f cd 02 c0       	push   $0xc002cd9f
c0027a82:	68 c0 c8 02 c0       	push   $0xc002c8c0
c0027a87:	68 69 01 00 00       	push   $0x169
c0027a8c:	68 a3 e7 02 c0       	push   $0xc002e7a3
c0027a91:	e8 79 fd ff ff       	call   c002780f <debug_panic>
  ASSERT (b != NULL);
c0027a96:	83 ec 0c             	sub    $0xc,%esp
c0027a99:	68 bb e7 02 c0       	push   $0xc002e7bb
c0027a9e:	68 9f cd 02 c0       	push   $0xc002cd9f
c0027aa3:	68 c0 c8 02 c0       	push   $0xc002c8c0
c0027aa8:	68 6a 01 00 00       	push   $0x16a
c0027aad:	68 a3 e7 02 c0       	push   $0xc002e7a3
c0027ab2:	e8 58 fd ff ff       	call   c002780f <debug_panic>
  ASSERT (less != NULL);
c0027ab7:	83 ec 0c             	sub    $0xc,%esp
c0027aba:	68 c5 e7 02 c0       	push   $0xc002e7c5
c0027abf:	68 9f cd 02 c0       	push   $0xc002cd9f
c0027ac4:	68 c0 c8 02 c0       	push   $0xc002c8c0
c0027ac9:	68 6b 01 00 00       	push   $0x16b
c0027ace:	68 a3 e7 02 c0       	push   $0xc002e7a3
c0027ad3:	e8 37 fd ff ff       	call   c002780f <debug_panic>
  ASSERT (a != b);
c0027ad8:	83 ec 0c             	sub    $0xc,%esp
c0027adb:	68 d2 e7 02 c0       	push   $0xc002e7d2
c0027ae0:	68 9f cd 02 c0       	push   $0xc002cd9f
c0027ae5:	68 c0 c8 02 c0       	push   $0xc002c8c0
c0027aea:	68 6c 01 00 00       	push   $0x16c
c0027aef:	68 a3 e7 02 c0       	push   $0xc002e7a3
c0027af4:	e8 16 fd ff ff       	call   c002780f <debug_panic>

c0027af9 <is_sorted>:
{
c0027af9:	55                   	push   %ebp
c0027afa:	57                   	push   %edi
c0027afb:	56                   	push   %esi
c0027afc:	53                   	push   %ebx
c0027afd:	83 ec 0c             	sub    $0xc,%esp
c0027b00:	89 c3                	mov    %eax,%ebx
c0027b02:	89 d6                	mov    %edx,%esi
c0027b04:	89 cd                	mov    %ecx,%ebp
c0027b06:	8b 7c 24 20          	mov    0x20(%esp),%edi
  if (a != b)
c0027b0a:	39 d0                	cmp    %edx,%eax
c0027b0c:	74 2e                	je     c0027b3c <is_sorted+0x43>
    while ((a = list_next (a)) != b) 
c0027b0e:	83 ec 0c             	sub    $0xc,%esp
c0027b11:	53                   	push   %ebx
c0027b12:	e8 12 fe ff ff       	call   c0027929 <list_next>
c0027b17:	83 c4 10             	add    $0x10,%esp
c0027b1a:	89 c3                	mov    %eax,%ebx
c0027b1c:	39 c6                	cmp    %eax,%esi
c0027b1e:	74 20                	je     c0027b40 <is_sorted+0x47>
      if (less (a, list_prev (a), aux))
c0027b20:	83 ec 0c             	sub    $0xc,%esp
c0027b23:	53                   	push   %ebx
c0027b24:	e8 a8 fe ff ff       	call   c00279d1 <list_prev>
c0027b29:	83 c4 0c             	add    $0xc,%esp
c0027b2c:	57                   	push   %edi
c0027b2d:	50                   	push   %eax
c0027b2e:	53                   	push   %ebx
c0027b2f:	ff d5                	call   *%ebp
c0027b31:	83 c4 10             	add    $0x10,%esp
c0027b34:	84 c0                	test   %al,%al
c0027b36:	74 d6                	je     c0027b0e <is_sorted+0x15>
        return false;
c0027b38:	b0 00                	mov    $0x0,%al
c0027b3a:	eb 06                	jmp    c0027b42 <is_sorted+0x49>
  return true;
c0027b3c:	b0 01                	mov    $0x1,%al
c0027b3e:	eb 02                	jmp    c0027b42 <is_sorted+0x49>
c0027b40:	b0 01                	mov    $0x1,%al
}
c0027b42:	83 c4 0c             	add    $0xc,%esp
c0027b45:	5b                   	pop    %ebx
c0027b46:	5e                   	pop    %esi
c0027b47:	5f                   	pop    %edi
c0027b48:	5d                   	pop    %ebp
c0027b49:	c3                   	ret    

c0027b4a <list_rend>:
{
c0027b4a:	83 ec 0c             	sub    $0xc,%esp
c0027b4d:	8b 44 24 10          	mov    0x10(%esp),%eax
  ASSERT (list != NULL);
c0027b51:	85 c0                	test   %eax,%eax
c0027b53:	74 04                	je     c0027b59 <list_rend+0xf>
}
c0027b55:	83 c4 0c             	add    $0xc,%esp
c0027b58:	c3                   	ret    
  ASSERT (list != NULL);
c0027b59:	83 ec 0c             	sub    $0xc,%esp
c0027b5c:	68 96 e7 02 c0       	push   $0xc002e796
c0027b61:	68 9f cd 02 c0       	push   $0xc002cd9f
c0027b66:	68 30 c9 02 c0       	push   $0xc002c930
c0027b6b:	68 87 00 00 00       	push   $0x87
c0027b70:	68 a3 e7 02 c0       	push   $0xc002e7a3
c0027b75:	e8 95 fc ff ff       	call   c002780f <debug_panic>

c0027b7a <list_head>:
{
c0027b7a:	83 ec 0c             	sub    $0xc,%esp
c0027b7d:	8b 44 24 10          	mov    0x10(%esp),%eax
  ASSERT (list != NULL);
c0027b81:	85 c0                	test   %eax,%eax
c0027b83:	74 04                	je     c0027b89 <list_head+0xf>
}
c0027b85:	83 c4 0c             	add    $0xc,%esp
c0027b88:	c3                   	ret    
  ASSERT (list != NULL);
c0027b89:	83 ec 0c             	sub    $0xc,%esp
c0027b8c:	68 96 e7 02 c0       	push   $0xc002e796
c0027b91:	68 9f cd 02 c0       	push   $0xc002cd9f
c0027b96:	68 24 c9 02 c0       	push   $0xc002c924
c0027b9b:	68 99 00 00 00       	push   $0x99
c0027ba0:	68 a3 e7 02 c0       	push   $0xc002e7a3
c0027ba5:	e8 65 fc ff ff       	call   c002780f <debug_panic>

c0027baa <list_tail>:
{
c0027baa:	83 ec 0c             	sub    $0xc,%esp
c0027bad:	8b 44 24 10          	mov    0x10(%esp),%eax
  ASSERT (list != NULL);
c0027bb1:	85 c0                	test   %eax,%eax
c0027bb3:	74 07                	je     c0027bbc <list_tail+0x12>
  return &list->tail;
c0027bb5:	83 c0 08             	add    $0x8,%eax
}
c0027bb8:	83 c4 0c             	add    $0xc,%esp
c0027bbb:	c3                   	ret    
  ASSERT (list != NULL);
c0027bbc:	83 ec 0c             	sub    $0xc,%esp
c0027bbf:	68 96 e7 02 c0       	push   $0xc002e796
c0027bc4:	68 9f cd 02 c0       	push   $0xc002cd9f
c0027bc9:	68 18 c9 02 c0       	push   $0xc002c918
c0027bce:	68 a1 00 00 00       	push   $0xa1
c0027bd3:	68 a3 e7 02 c0       	push   $0xc002e7a3
c0027bd8:	e8 32 fc ff ff       	call   c002780f <debug_panic>

c0027bdd <list_insert>:
{
c0027bdd:	83 ec 0c             	sub    $0xc,%esp
c0027be0:	8b 44 24 10          	mov    0x10(%esp),%eax
c0027be4:	8b 54 24 14          	mov    0x14(%esp),%edx
  return elem != NULL && elem->prev != NULL && elem->next != NULL;
c0027be8:	85 c0                	test   %eax,%eax
c0027bea:	74 2c                	je     c0027c18 <list_insert+0x3b>
c0027bec:	83 38 00             	cmpl   $0x0,(%eax)
c0027bef:	74 1c                	je     c0027c0d <list_insert+0x30>
c0027bf1:	83 78 04 00          	cmpl   $0x0,0x4(%eax)
c0027bf5:	74 16                	je     c0027c0d <list_insert+0x30>
  ASSERT (elem != NULL);
c0027bf7:	85 d2                	test   %edx,%edx
c0027bf9:	74 3e                	je     c0027c39 <list_insert+0x5c>
  elem->prev = before->prev;
c0027bfb:	8b 08                	mov    (%eax),%ecx
c0027bfd:	89 0a                	mov    %ecx,(%edx)
  elem->next = before;
c0027bff:	89 42 04             	mov    %eax,0x4(%edx)
  before->prev->next = elem;
c0027c02:	8b 08                	mov    (%eax),%ecx
c0027c04:	89 51 04             	mov    %edx,0x4(%ecx)
  before->prev = elem;
c0027c07:	89 10                	mov    %edx,(%eax)
}
c0027c09:	83 c4 0c             	add    $0xc,%esp
c0027c0c:	c3                   	ret    
  return elem != NULL && elem->prev != NULL && elem->next == NULL;
c0027c0d:	83 38 00             	cmpl   $0x0,(%eax)
c0027c10:	74 06                	je     c0027c18 <list_insert+0x3b>
c0027c12:	83 78 04 00          	cmpl   $0x0,0x4(%eax)
c0027c16:	74 df                	je     c0027bf7 <list_insert+0x1a>
  ASSERT (is_interior (before) || is_tail (before));
c0027c18:	83 ec 0c             	sub    $0xc,%esp
c0027c1b:	68 a8 e8 02 c0       	push   $0xc002e8a8
c0027c20:	68 9f cd 02 c0       	push   $0xc002cd9f
c0027c25:	68 0c c9 02 c0       	push   $0xc002c90c
c0027c2a:	68 ab 00 00 00       	push   $0xab
c0027c2f:	68 a3 e7 02 c0       	push   $0xc002e7a3
c0027c34:	e8 d6 fb ff ff       	call   c002780f <debug_panic>
  ASSERT (elem != NULL);
c0027c39:	83 ec 0c             	sub    $0xc,%esp
c0027c3c:	68 d9 e7 02 c0       	push   $0xc002e7d9
c0027c41:	68 9f cd 02 c0       	push   $0xc002cd9f
c0027c46:	68 0c c9 02 c0       	push   $0xc002c90c
c0027c4b:	68 ac 00 00 00       	push   $0xac
c0027c50:	68 a3 e7 02 c0       	push   $0xc002e7a3
c0027c55:	e8 b5 fb ff ff       	call   c002780f <debug_panic>

c0027c5a <list_splice>:
{
c0027c5a:	56                   	push   %esi
c0027c5b:	53                   	push   %ebx
c0027c5c:	83 ec 04             	sub    $0x4,%esp
c0027c5f:	8b 5c 24 10          	mov    0x10(%esp),%ebx
c0027c63:	8b 74 24 14          	mov    0x14(%esp),%esi
c0027c67:	8b 44 24 18          	mov    0x18(%esp),%eax
  return elem != NULL && elem->prev != NULL && elem->next != NULL;
c0027c6b:	85 db                	test   %ebx,%ebx
c0027c6d:	74 64                	je     c0027cd3 <list_splice+0x79>
c0027c6f:	83 3b 00             	cmpl   $0x0,(%ebx)
c0027c72:	74 54                	je     c0027cc8 <list_splice+0x6e>
c0027c74:	83 7b 04 00          	cmpl   $0x0,0x4(%ebx)
c0027c78:	74 4e                	je     c0027cc8 <list_splice+0x6e>
  if (first == last)
c0027c7a:	39 c6                	cmp    %eax,%esi
c0027c7c:	74 44                	je     c0027cc2 <list_splice+0x68>
  last = list_prev (last);
c0027c7e:	83 ec 0c             	sub    $0xc,%esp
c0027c81:	50                   	push   %eax
c0027c82:	e8 4a fd ff ff       	call   c00279d1 <list_prev>
c0027c87:	83 c4 10             	add    $0x10,%esp
  return elem != NULL && elem->prev != NULL && elem->next != NULL;
c0027c8a:	85 f6                	test   %esi,%esi
c0027c8c:	74 66                	je     c0027cf4 <list_splice+0x9a>
c0027c8e:	8b 16                	mov    (%esi),%edx
c0027c90:	85 d2                	test   %edx,%edx
c0027c92:	74 60                	je     c0027cf4 <list_splice+0x9a>
c0027c94:	83 7e 04 00          	cmpl   $0x0,0x4(%esi)
c0027c98:	74 5a                	je     c0027cf4 <list_splice+0x9a>
c0027c9a:	85 c0                	test   %eax,%eax
c0027c9c:	74 77                	je     c0027d15 <list_splice+0xbb>
c0027c9e:	83 38 00             	cmpl   $0x0,(%eax)
c0027ca1:	74 72                	je     c0027d15 <list_splice+0xbb>
c0027ca3:	8b 48 04             	mov    0x4(%eax),%ecx
c0027ca6:	85 c9                	test   %ecx,%ecx
c0027ca8:	74 6b                	je     c0027d15 <list_splice+0xbb>
  first->prev->next = last->next;
c0027caa:	89 4a 04             	mov    %ecx,0x4(%edx)
  last->next->prev = first->prev;
c0027cad:	8b 50 04             	mov    0x4(%eax),%edx
c0027cb0:	8b 0e                	mov    (%esi),%ecx
c0027cb2:	89 0a                	mov    %ecx,(%edx)
  first->prev = before->prev;
c0027cb4:	8b 13                	mov    (%ebx),%edx
c0027cb6:	89 16                	mov    %edx,(%esi)
  last->next = before;
c0027cb8:	89 58 04             	mov    %ebx,0x4(%eax)
  before->prev->next = first;
c0027cbb:	8b 13                	mov    (%ebx),%edx
c0027cbd:	89 72 04             	mov    %esi,0x4(%edx)
  before->prev = last;
c0027cc0:	89 03                	mov    %eax,(%ebx)
}
c0027cc2:	83 c4 04             	add    $0x4,%esp
c0027cc5:	5b                   	pop    %ebx
c0027cc6:	5e                   	pop    %esi
c0027cc7:	c3                   	ret    
  return elem != NULL && elem->prev != NULL && elem->next == NULL;
c0027cc8:	83 3b 00             	cmpl   $0x0,(%ebx)
c0027ccb:	74 06                	je     c0027cd3 <list_splice+0x79>
c0027ccd:	83 7b 04 00          	cmpl   $0x0,0x4(%ebx)
c0027cd1:	74 a7                	je     c0027c7a <list_splice+0x20>
  ASSERT (is_interior (before) || is_tail (before));
c0027cd3:	83 ec 0c             	sub    $0xc,%esp
c0027cd6:	68 a8 e8 02 c0       	push   $0xc002e8a8
c0027cdb:	68 9f cd 02 c0       	push   $0xc002cd9f
c0027ce0:	68 00 c9 02 c0       	push   $0xc002c900
c0027ce5:	68 bb 00 00 00       	push   $0xbb
c0027cea:	68 a3 e7 02 c0       	push   $0xc002e7a3
c0027cef:	e8 1b fb ff ff       	call   c002780f <debug_panic>
  ASSERT (is_interior (first));
c0027cf4:	83 ec 0c             	sub    $0xc,%esp
c0027cf7:	68 e6 e7 02 c0       	push   $0xc002e7e6
c0027cfc:	68 9f cd 02 c0       	push   $0xc002cd9f
c0027d01:	68 00 c9 02 c0       	push   $0xc002c900
c0027d06:	68 c0 00 00 00       	push   $0xc0
c0027d0b:	68 a3 e7 02 c0       	push   $0xc002e7a3
c0027d10:	e8 fa fa ff ff       	call   c002780f <debug_panic>
  ASSERT (is_interior (last));
c0027d15:	83 ec 0c             	sub    $0xc,%esp
c0027d18:	68 fa e7 02 c0       	push   $0xc002e7fa
c0027d1d:	68 9f cd 02 c0       	push   $0xc002cd9f
c0027d22:	68 00 c9 02 c0       	push   $0xc002c900
c0027d27:	68 c1 00 00 00       	push   $0xc1
c0027d2c:	68 a3 e7 02 c0       	push   $0xc002e7a3
c0027d31:	e8 d9 fa ff ff       	call   c002780f <debug_panic>

c0027d36 <list_push_front>:
{
c0027d36:	83 ec 18             	sub    $0x18,%esp
  list_insert (list_begin (list), elem);
c0027d39:	ff 74 24 1c          	pushl  0x1c(%esp)
c0027d3d:	e8 b7 fb ff ff       	call   c00278f9 <list_begin>
c0027d42:	83 c4 08             	add    $0x8,%esp
c0027d45:	ff 74 24 1c          	pushl  0x1c(%esp)
c0027d49:	50                   	push   %eax
c0027d4a:	e8 8e fe ff ff       	call   c0027bdd <list_insert>
}
c0027d4f:	83 c4 1c             	add    $0x1c,%esp
c0027d52:	c3                   	ret    

c0027d53 <list_push_back>:
{
c0027d53:	83 ec 18             	sub    $0x18,%esp
  list_insert (list_end (list), elem);
c0027d56:	ff 74 24 1c          	pushl  0x1c(%esp)
c0027d5a:	e8 12 fc ff ff       	call   c0027971 <list_end>
c0027d5f:	83 c4 08             	add    $0x8,%esp
c0027d62:	ff 74 24 1c          	pushl  0x1c(%esp)
c0027d66:	50                   	push   %eax
c0027d67:	e8 71 fe ff ff       	call   c0027bdd <list_insert>
}
c0027d6c:	83 c4 1c             	add    $0x1c,%esp
c0027d6f:	c3                   	ret    

c0027d70 <list_remove>:
{
c0027d70:	83 ec 0c             	sub    $0xc,%esp
c0027d73:	8b 44 24 10          	mov    0x10(%esp),%eax
  return elem != NULL && elem->prev != NULL && elem->next != NULL;
c0027d77:	85 c0                	test   %eax,%eax
c0027d79:	74 1e                	je     c0027d99 <list_remove+0x29>
c0027d7b:	8b 10                	mov    (%eax),%edx
c0027d7d:	85 d2                	test   %edx,%edx
c0027d7f:	74 18                	je     c0027d99 <list_remove+0x29>
c0027d81:	8b 48 04             	mov    0x4(%eax),%ecx
c0027d84:	85 c9                	test   %ecx,%ecx
c0027d86:	74 11                	je     c0027d99 <list_remove+0x29>
  elem->prev->next = elem->next;
c0027d88:	89 4a 04             	mov    %ecx,0x4(%edx)
  elem->next->prev = elem->prev;
c0027d8b:	8b 50 04             	mov    0x4(%eax),%edx
c0027d8e:	8b 08                	mov    (%eax),%ecx
c0027d90:	89 0a                	mov    %ecx,(%edx)
  return elem->next;
c0027d92:	8b 40 04             	mov    0x4(%eax),%eax
}
c0027d95:	83 c4 0c             	add    $0xc,%esp
c0027d98:	c3                   	ret    
  ASSERT (is_interior (elem));
c0027d99:	83 ec 0c             	sub    $0xc,%esp
c0027d9c:	68 0d e8 02 c0       	push   $0xc002e80d
c0027da1:	68 9f cd 02 c0       	push   $0xc002cd9f
c0027da6:	68 f4 c8 02 c0       	push   $0xc002c8f4
c0027dab:	68 fb 00 00 00       	push   $0xfb
c0027db0:	68 a3 e7 02 c0       	push   $0xc002e7a3
c0027db5:	e8 55 fa ff ff       	call   c002780f <debug_panic>

c0027dba <list_size>:
{
c0027dba:	57                   	push   %edi
c0027dbb:	56                   	push   %esi
c0027dbc:	53                   	push   %ebx
c0027dbd:	8b 7c 24 10          	mov    0x10(%esp),%edi
  for (e = list_begin (list); e != list_end (list); e = list_next (e))
c0027dc1:	83 ec 0c             	sub    $0xc,%esp
c0027dc4:	57                   	push   %edi
c0027dc5:	e8 2f fb ff ff       	call   c00278f9 <list_begin>
c0027dca:	83 c4 10             	add    $0x10,%esp
c0027dcd:	89 c3                	mov    %eax,%ebx
  size_t cnt = 0;
c0027dcf:	be 00 00 00 00       	mov    $0x0,%esi
  for (e = list_begin (list); e != list_end (list); e = list_next (e))
c0027dd4:	eb 0f                	jmp    c0027de5 <list_size+0x2b>
    cnt++;
c0027dd6:	46                   	inc    %esi
  for (e = list_begin (list); e != list_end (list); e = list_next (e))
c0027dd7:	83 ec 0c             	sub    $0xc,%esp
c0027dda:	53                   	push   %ebx
c0027ddb:	e8 49 fb ff ff       	call   c0027929 <list_next>
c0027de0:	83 c4 10             	add    $0x10,%esp
c0027de3:	89 c3                	mov    %eax,%ebx
c0027de5:	83 ec 0c             	sub    $0xc,%esp
c0027de8:	57                   	push   %edi
c0027de9:	e8 83 fb ff ff       	call   c0027971 <list_end>
c0027dee:	83 c4 10             	add    $0x10,%esp
c0027df1:	39 c3                	cmp    %eax,%ebx
c0027df3:	75 e1                	jne    c0027dd6 <list_size+0x1c>
}
c0027df5:	89 f0                	mov    %esi,%eax
c0027df7:	5b                   	pop    %ebx
c0027df8:	5e                   	pop    %esi
c0027df9:	5f                   	pop    %edi
c0027dfa:	c3                   	ret    

c0027dfb <list_empty>:
{
c0027dfb:	56                   	push   %esi
c0027dfc:	53                   	push   %ebx
c0027dfd:	83 ec 10             	sub    $0x10,%esp
c0027e00:	8b 5c 24 1c          	mov    0x1c(%esp),%ebx
  return list_begin (list) == list_end (list);
c0027e04:	53                   	push   %ebx
c0027e05:	e8 ef fa ff ff       	call   c00278f9 <list_begin>
c0027e0a:	89 c6                	mov    %eax,%esi
c0027e0c:	89 1c 24             	mov    %ebx,(%esp)
c0027e0f:	e8 5d fb ff ff       	call   c0027971 <list_end>
c0027e14:	39 c6                	cmp    %eax,%esi
c0027e16:	0f 94 c0             	sete   %al
}
c0027e19:	83 c4 14             	add    $0x14,%esp
c0027e1c:	5b                   	pop    %ebx
c0027e1d:	5e                   	pop    %esi
c0027e1e:	c3                   	ret    

c0027e1f <list_front>:
{
c0027e1f:	53                   	push   %ebx
c0027e20:	83 ec 14             	sub    $0x14,%esp
c0027e23:	8b 5c 24 1c          	mov    0x1c(%esp),%ebx
  ASSERT (!list_empty (list));
c0027e27:	53                   	push   %ebx
c0027e28:	e8 ce ff ff ff       	call   c0027dfb <list_empty>
c0027e2d:	83 c4 10             	add    $0x10,%esp
c0027e30:	84 c0                	test   %al,%al
c0027e32:	75 08                	jne    c0027e3c <list_front+0x1d>
  return list->head.next;
c0027e34:	8b 43 04             	mov    0x4(%ebx),%eax
}
c0027e37:	83 c4 08             	add    $0x8,%esp
c0027e3a:	5b                   	pop    %ebx
c0027e3b:	c3                   	ret    
  ASSERT (!list_empty (list));
c0027e3c:	83 ec 0c             	sub    $0xc,%esp
c0027e3f:	68 20 e8 02 c0       	push   $0xc002e820
c0027e44:	68 9f cd 02 c0       	push   $0xc002cd9f
c0027e49:	68 e8 c8 02 c0       	push   $0xc002c8e8
c0027e4e:	68 1a 01 00 00       	push   $0x11a
c0027e53:	68 a3 e7 02 c0       	push   $0xc002e7a3
c0027e58:	e8 b2 f9 ff ff       	call   c002780f <debug_panic>

c0027e5d <list_pop_front>:
{
c0027e5d:	53                   	push   %ebx
c0027e5e:	83 ec 14             	sub    $0x14,%esp
  struct list_elem *front = list_front (list);
c0027e61:	ff 74 24 1c          	pushl  0x1c(%esp)
c0027e65:	e8 b5 ff ff ff       	call   c0027e1f <list_front>
c0027e6a:	89 c3                	mov    %eax,%ebx
  list_remove (front);
c0027e6c:	89 04 24             	mov    %eax,(%esp)
c0027e6f:	e8 fc fe ff ff       	call   c0027d70 <list_remove>
}
c0027e74:	89 d8                	mov    %ebx,%eax
c0027e76:	83 c4 18             	add    $0x18,%esp
c0027e79:	5b                   	pop    %ebx
c0027e7a:	c3                   	ret    

c0027e7b <list_back>:
{
c0027e7b:	53                   	push   %ebx
c0027e7c:	83 ec 14             	sub    $0x14,%esp
c0027e7f:	8b 5c 24 1c          	mov    0x1c(%esp),%ebx
  ASSERT (!list_empty (list));
c0027e83:	53                   	push   %ebx
c0027e84:	e8 72 ff ff ff       	call   c0027dfb <list_empty>
c0027e89:	83 c4 10             	add    $0x10,%esp
c0027e8c:	84 c0                	test   %al,%al
c0027e8e:	75 08                	jne    c0027e98 <list_back+0x1d>
  return list->tail.prev;
c0027e90:	8b 43 08             	mov    0x8(%ebx),%eax
}
c0027e93:	83 c4 08             	add    $0x8,%esp
c0027e96:	5b                   	pop    %ebx
c0027e97:	c3                   	ret    
  ASSERT (!list_empty (list));
c0027e98:	83 ec 0c             	sub    $0xc,%esp
c0027e9b:	68 20 e8 02 c0       	push   $0xc002e820
c0027ea0:	68 9f cd 02 c0       	push   $0xc002cd9f
c0027ea5:	68 dc c8 02 c0       	push   $0xc002c8dc
c0027eaa:	68 23 01 00 00       	push   $0x123
c0027eaf:	68 a3 e7 02 c0       	push   $0xc002e7a3
c0027eb4:	e8 56 f9 ff ff       	call   c002780f <debug_panic>

c0027eb9 <list_pop_back>:
{
c0027eb9:	53                   	push   %ebx
c0027eba:	83 ec 14             	sub    $0x14,%esp
  struct list_elem *back = list_back (list);
c0027ebd:	ff 74 24 1c          	pushl  0x1c(%esp)
c0027ec1:	e8 b5 ff ff ff       	call   c0027e7b <list_back>
c0027ec6:	89 c3                	mov    %eax,%ebx
  list_remove (back);
c0027ec8:	89 04 24             	mov    %eax,(%esp)
c0027ecb:	e8 a0 fe ff ff       	call   c0027d70 <list_remove>
}
c0027ed0:	89 d8                	mov    %ebx,%eax
c0027ed2:	83 c4 18             	add    $0x18,%esp
c0027ed5:	5b                   	pop    %ebx
c0027ed6:	c3                   	ret    

c0027ed7 <list_reverse>:
{
c0027ed7:	56                   	push   %esi
c0027ed8:	53                   	push   %ebx
c0027ed9:	83 ec 10             	sub    $0x10,%esp
c0027edc:	8b 74 24 1c          	mov    0x1c(%esp),%esi
  if (!list_empty (list)) 
c0027ee0:	56                   	push   %esi
c0027ee1:	e8 15 ff ff ff       	call   c0027dfb <list_empty>
c0027ee6:	83 c4 10             	add    $0x10,%esp
c0027ee9:	84 c0                	test   %al,%al
c0027eeb:	74 06                	je     c0027ef3 <list_reverse+0x1c>
}
c0027eed:	83 c4 04             	add    $0x4,%esp
c0027ef0:	5b                   	pop    %ebx
c0027ef1:	5e                   	pop    %esi
c0027ef2:	c3                   	ret    
      for (e = list_begin (list); e != list_end (list); e = e->prev)
c0027ef3:	83 ec 0c             	sub    $0xc,%esp
c0027ef6:	56                   	push   %esi
c0027ef7:	e8 fd f9 ff ff       	call   c00278f9 <list_begin>
c0027efc:	83 c4 10             	add    $0x10,%esp
c0027eff:	89 c3                	mov    %eax,%ebx
c0027f01:	eb 0c                	jmp    c0027f0f <list_reverse+0x38>
  struct list_elem *t = *a;
c0027f03:	8b 13                	mov    (%ebx),%edx
  *a = *b;
c0027f05:	8b 43 04             	mov    0x4(%ebx),%eax
c0027f08:	89 03                	mov    %eax,(%ebx)
  *b = t;
c0027f0a:	89 53 04             	mov    %edx,0x4(%ebx)
      for (e = list_begin (list); e != list_end (list); e = e->prev)
c0027f0d:	89 c3                	mov    %eax,%ebx
c0027f0f:	83 ec 0c             	sub    $0xc,%esp
c0027f12:	56                   	push   %esi
c0027f13:	e8 59 fa ff ff       	call   c0027971 <list_end>
c0027f18:	83 c4 10             	add    $0x10,%esp
c0027f1b:	39 c3                	cmp    %eax,%ebx
c0027f1d:	75 e4                	jne    c0027f03 <list_reverse+0x2c>
  struct list_elem *t = *a;
c0027f1f:	8b 46 04             	mov    0x4(%esi),%eax
  *a = *b;
c0027f22:	8b 56 08             	mov    0x8(%esi),%edx
c0027f25:	89 56 04             	mov    %edx,0x4(%esi)
  *b = t;
c0027f28:	89 46 08             	mov    %eax,0x8(%esi)
  struct list_elem *t = *a;
c0027f2b:	8b 0a                	mov    (%edx),%ecx
  *a = *b;
c0027f2d:	8b 58 04             	mov    0x4(%eax),%ebx
c0027f30:	89 1a                	mov    %ebx,(%edx)
  *b = t;
c0027f32:	89 48 04             	mov    %ecx,0x4(%eax)
}
c0027f35:	eb b6                	jmp    c0027eed <list_reverse+0x16>

c0027f37 <list_sort>:
/* Sorts LIST according to LESS given auxiliary data AUX, using a
   natural iterative merge sort that runs in O(n lg n) time and
   O(1) space in the number of elements in LIST. */
void
list_sort (struct list *list, list_less_func *less, void *aux)
{
c0027f37:	55                   	push   %ebp
c0027f38:	57                   	push   %edi
c0027f39:	56                   	push   %esi
c0027f3a:	53                   	push   %ebx
c0027f3b:	83 ec 1c             	sub    $0x1c,%esp
c0027f3e:	8b 6c 24 34          	mov    0x34(%esp),%ebp
c0027f42:	8b 7c 24 38          	mov    0x38(%esp),%edi
  size_t output_run_cnt;        /* Number of runs output in current pass. */

  ASSERT (list != NULL);
c0027f46:	83 7c 24 30 00       	cmpl   $0x0,0x30(%esp)
c0027f4b:	74 29                	je     c0027f76 <list_sort+0x3f>
  ASSERT (less != NULL);
c0027f4d:	85 ed                	test   %ebp,%ebp
c0027f4f:	0f 85 f9 01 00 00    	jne    c002814e <list_sort+0x217>
c0027f55:	83 ec 0c             	sub    $0xc,%esp
c0027f58:	68 c5 e7 02 c0       	push   $0xc002e7c5
c0027f5d:	68 9f cd 02 c0       	push   $0xc002cd9f
c0027f62:	68 d0 c8 02 c0       	push   $0xc002c8d0
c0027f67:	68 9a 01 00 00       	push   $0x19a
c0027f6c:	68 a3 e7 02 c0       	push   $0xc002e7a3
c0027f71:	e8 99 f8 ff ff       	call   c002780f <debug_panic>
  ASSERT (list != NULL);
c0027f76:	83 ec 0c             	sub    $0xc,%esp
c0027f79:	68 96 e7 02 c0       	push   $0xc002e796
c0027f7e:	68 9f cd 02 c0       	push   $0xc002cd9f
c0027f83:	68 d0 c8 02 c0       	push   $0xc002c8d0
c0027f88:	68 99 01 00 00       	push   $0x199
c0027f8d:	68 a3 e7 02 c0       	push   $0xc002e7a3
c0027f92:	e8 78 f8 ff ff       	call   c002780f <debug_panic>
  ASSERT (a0 != NULL);
c0027f97:	83 ec 0c             	sub    $0xc,%esp
c0027f9a:	68 33 e8 02 c0       	push   $0xc002e833
c0027f9f:	68 9f cd 02 c0       	push   $0xc002cd9f
c0027fa4:	68 b0 c8 02 c0       	push   $0xc002c8b0
c0027fa9:	68 80 01 00 00       	push   $0x180
c0027fae:	68 a3 e7 02 c0       	push   $0xc002e7a3
c0027fb3:	e8 57 f8 ff ff       	call   c002780f <debug_panic>
  ASSERT (a1b0 != NULL);
c0027fb8:	83 ec 0c             	sub    $0xc,%esp
c0027fbb:	68 3e e8 02 c0       	push   $0xc002e83e
c0027fc0:	68 9f cd 02 c0       	push   $0xc002cd9f
c0027fc5:	68 b0 c8 02 c0       	push   $0xc002c8b0
c0027fca:	68 81 01 00 00       	push   $0x181
c0027fcf:	68 a3 e7 02 c0       	push   $0xc002e7a3
c0027fd4:	e8 36 f8 ff ff       	call   c002780f <debug_panic>
  ASSERT (b1 != NULL);
c0027fd9:	83 ec 0c             	sub    $0xc,%esp
c0027fdc:	68 4b e8 02 c0       	push   $0xc002e84b
c0027fe1:	68 9f cd 02 c0       	push   $0xc002cd9f
c0027fe6:	68 b0 c8 02 c0       	push   $0xc002c8b0
c0027feb:	68 82 01 00 00       	push   $0x182
c0027ff0:	68 a3 e7 02 c0       	push   $0xc002e7a3
c0027ff5:	e8 15 f8 ff ff       	call   c002780f <debug_panic>
  ASSERT (is_sorted (a0, a1b0, less, aux));
c0027ffa:	83 ec 0c             	sub    $0xc,%esp
c0027ffd:	68 d4 e8 02 c0       	push   $0xc002e8d4
c0028002:	68 9f cd 02 c0       	push   $0xc002cd9f
c0028007:	68 b0 c8 02 c0       	push   $0xc002c8b0
c002800c:	68 84 01 00 00       	push   $0x184
c0028011:	68 a3 e7 02 c0       	push   $0xc002e7a3
c0028016:	e8 f4 f7 ff ff       	call   c002780f <debug_panic>
  ASSERT (is_sorted (a1b0, b1, less, aux));
c002801b:	83 ec 0c             	sub    $0xc,%esp
c002801e:	68 f4 e8 02 c0       	push   $0xc002e8f4
c0028023:	68 9f cd 02 c0       	push   $0xc002cd9f
c0028028:	68 b0 c8 02 c0       	push   $0xc002c8b0
c002802d:	68 85 01 00 00       	push   $0x185
c0028032:	68 a3 e7 02 c0       	push   $0xc002e7a3
c0028037:	e8 d3 f7 ff ff       	call   c002780f <debug_panic>
        a1b0 = list_next (a1b0);
c002803c:	83 ec 0c             	sub    $0xc,%esp
c002803f:	53                   	push   %ebx
c0028040:	e8 e4 f8 ff ff       	call   c0027929 <list_next>
c0028045:	89 c3                	mov    %eax,%ebx
        list_splice (a0, list_prev (a1b0), a1b0);
c0028047:	89 04 24             	mov    %eax,(%esp)
c002804a:	e8 82 f9 ff ff       	call   c00279d1 <list_prev>
c002804f:	83 c4 0c             	add    $0xc,%esp
c0028052:	53                   	push   %ebx
c0028053:	50                   	push   %eax
c0028054:	56                   	push   %esi
c0028055:	e8 00 fc ff ff       	call   c0027c5a <list_splice>
c002805a:	83 c4 10             	add    $0x10,%esp
  while (a0 != a1b0 && a1b0 != b1)
c002805d:	39 f3                	cmp    %esi,%ebx
c002805f:	74 25                	je     c0028086 <list_sort+0x14f>
c0028061:	39 5c 24 08          	cmp    %ebx,0x8(%esp)
c0028065:	74 1f                	je     c0028086 <list_sort+0x14f>
    if (!less (a1b0, a0, aux)) 
c0028067:	83 ec 04             	sub    $0x4,%esp
c002806a:	57                   	push   %edi
c002806b:	56                   	push   %esi
c002806c:	53                   	push   %ebx
c002806d:	ff d5                	call   *%ebp
c002806f:	83 c4 10             	add    $0x10,%esp
c0028072:	84 c0                	test   %al,%al
c0028074:	75 c6                	jne    c002803c <list_sort+0x105>
      a0 = list_next (a0);
c0028076:	83 ec 0c             	sub    $0xc,%esp
c0028079:	56                   	push   %esi
c002807a:	e8 aa f8 ff ff       	call   c0027929 <list_next>
c002807f:	83 c4 10             	add    $0x10,%esp
c0028082:	89 c6                	mov    %eax,%esi
c0028084:	eb d7                	jmp    c002805d <list_sort+0x126>
{
c0028086:	8b 74 24 08          	mov    0x8(%esp),%esi
      struct list_elem *a0;     /* Start of first run. */
      struct list_elem *a1b0;   /* End of first run, start of second. */
      struct list_elem *b1;     /* End of second run. */

      output_run_cnt = 0;
      for (a0 = list_begin (list); a0 != list_end (list); a0 = b1)
c002808a:	83 ec 0c             	sub    $0xc,%esp
c002808d:	ff 74 24 3c          	pushl  0x3c(%esp)
c0028091:	e8 db f8 ff ff       	call   c0027971 <list_end>
c0028096:	83 c4 10             	add    $0x10,%esp
c0028099:	39 c6                	cmp    %eax,%esi
c002809b:	0f 84 a6 00 00 00    	je     c0028147 <list_sort+0x210>
        {
          /* Each iteration produces one output run. */
          output_run_cnt++;
c00280a1:	ff 44 24 0c          	incl   0xc(%esp)

          /* Locate two adjacent runs of nondecreasing elements
             A0...A1B0 and A1B0...B1. */
          a1b0 = find_end_of_run (a0, list_end (list), less, aux);
c00280a5:	83 ec 0c             	sub    $0xc,%esp
c00280a8:	57                   	push   %edi
c00280a9:	89 e9                	mov    %ebp,%ecx
c00280ab:	89 c2                	mov    %eax,%edx
c00280ad:	89 f0                	mov    %esi,%eax
c00280af:	e8 62 f9 ff ff       	call   c0027a16 <find_end_of_run>
c00280b4:	89 c3                	mov    %eax,%ebx
          if (a1b0 == list_end (list))
c00280b6:	83 c4 04             	add    $0x4,%esp
c00280b9:	ff 74 24 3c          	pushl  0x3c(%esp)
c00280bd:	e8 af f8 ff ff       	call   c0027971 <list_end>
c00280c2:	83 c4 10             	add    $0x10,%esp
c00280c5:	39 c3                	cmp    %eax,%ebx
c00280c7:	74 7e                	je     c0028147 <list_sort+0x210>
            break;
          b1 = find_end_of_run (a1b0, list_end (list), less, aux);
c00280c9:	83 ec 0c             	sub    $0xc,%esp
c00280cc:	57                   	push   %edi
c00280cd:	89 e9                	mov    %ebp,%ecx
c00280cf:	89 c2                	mov    %eax,%edx
c00280d1:	89 d8                	mov    %ebx,%eax
c00280d3:	e8 3e f9 ff ff       	call   c0027a16 <find_end_of_run>
c00280d8:	89 44 24 18          	mov    %eax,0x18(%esp)
  ASSERT (a0 != NULL);
c00280dc:	83 c4 10             	add    $0x10,%esp
c00280df:	85 f6                	test   %esi,%esi
c00280e1:	0f 84 b0 fe ff ff    	je     c0027f97 <list_sort+0x60>
  ASSERT (a1b0 != NULL);
c00280e7:	85 db                	test   %ebx,%ebx
c00280e9:	0f 84 c9 fe ff ff    	je     c0027fb8 <list_sort+0x81>
  ASSERT (b1 != NULL);
c00280ef:	83 7c 24 08 00       	cmpl   $0x0,0x8(%esp)
c00280f4:	0f 84 df fe ff ff    	je     c0027fd9 <list_sort+0xa2>
  ASSERT (is_sorted (a0, a1b0, less, aux));
c00280fa:	83 ec 0c             	sub    $0xc,%esp
c00280fd:	57                   	push   %edi
c00280fe:	89 e9                	mov    %ebp,%ecx
c0028100:	89 da                	mov    %ebx,%edx
c0028102:	89 f0                	mov    %esi,%eax
c0028104:	e8 f0 f9 ff ff       	call   c0027af9 <is_sorted>
c0028109:	83 c4 10             	add    $0x10,%esp
c002810c:	84 c0                	test   %al,%al
c002810e:	0f 84 e6 fe ff ff    	je     c0027ffa <list_sort+0xc3>
  ASSERT (is_sorted (a1b0, b1, less, aux));
c0028114:	83 ec 0c             	sub    $0xc,%esp
c0028117:	57                   	push   %edi
c0028118:	89 e9                	mov    %ebp,%ecx
c002811a:	8b 54 24 18          	mov    0x18(%esp),%edx
c002811e:	89 d8                	mov    %ebx,%eax
c0028120:	e8 d4 f9 ff ff       	call   c0027af9 <is_sorted>
c0028125:	83 c4 10             	add    $0x10,%esp
c0028128:	84 c0                	test   %al,%al
c002812a:	0f 84 eb fe ff ff    	je     c002801b <list_sort+0xe4>
  while (a0 != a1b0 && a1b0 != b1)
c0028130:	39 de                	cmp    %ebx,%esi
c0028132:	0f 84 4e ff ff ff    	je     c0028086 <list_sort+0x14f>
c0028138:	3b 5c 24 08          	cmp    0x8(%esp),%ebx
c002813c:	0f 85 25 ff ff ff    	jne    c0028067 <list_sort+0x130>
c0028142:	e9 3f ff ff ff       	jmp    c0028086 <list_sort+0x14f>

          /* Merge the runs. */
          inplace_merge (a0, a1b0, b1, less, aux);
        }
    }
  while (output_run_cnt > 1);
c0028147:	83 7c 24 0c 01       	cmpl   $0x1,0xc(%esp)
c002814c:	76 1e                	jbe    c002816c <list_sort+0x235>
      for (a0 = list_begin (list); a0 != list_end (list); a0 = b1)
c002814e:	83 ec 0c             	sub    $0xc,%esp
c0028151:	ff 74 24 3c          	pushl  0x3c(%esp)
c0028155:	e8 9f f7 ff ff       	call   c00278f9 <list_begin>
c002815a:	83 c4 10             	add    $0x10,%esp
c002815d:	89 c6                	mov    %eax,%esi
      output_run_cnt = 0;
c002815f:	c7 44 24 0c 00 00 00 	movl   $0x0,0xc(%esp)
c0028166:	00 
      for (a0 = list_begin (list); a0 != list_end (list); a0 = b1)
c0028167:	e9 1e ff ff ff       	jmp    c002808a <list_sort+0x153>

  ASSERT (is_sorted (list_begin (list), list_end (list), less, aux));
c002816c:	83 ec 0c             	sub    $0xc,%esp
c002816f:	ff 74 24 3c          	pushl  0x3c(%esp)
c0028173:	e8 f9 f7 ff ff       	call   c0027971 <list_end>
c0028178:	83 c4 04             	add    $0x4,%esp
c002817b:	89 c3                	mov    %eax,%ebx
c002817d:	ff 74 24 3c          	pushl  0x3c(%esp)
c0028181:	e8 73 f7 ff ff       	call   c00278f9 <list_begin>
c0028186:	89 3c 24             	mov    %edi,(%esp)
c0028189:	89 e9                	mov    %ebp,%ecx
c002818b:	89 da                	mov    %ebx,%edx
c002818d:	e8 67 f9 ff ff       	call   c0027af9 <is_sorted>
c0028192:	83 c4 10             	add    $0x10,%esp
c0028195:	84 c0                	test   %al,%al
c0028197:	74 08                	je     c00281a1 <list_sort+0x26a>
}
c0028199:	83 c4 1c             	add    $0x1c,%esp
c002819c:	5b                   	pop    %ebx
c002819d:	5e                   	pop    %esi
c002819e:	5f                   	pop    %edi
c002819f:	5d                   	pop    %ebp
c00281a0:	c3                   	ret    
  ASSERT (is_sorted (list_begin (list), list_end (list), less, aux));
c00281a1:	83 ec 0c             	sub    $0xc,%esp
c00281a4:	68 14 e9 02 c0       	push   $0xc002e914
c00281a9:	68 9f cd 02 c0       	push   $0xc002cd9f
c00281ae:	68 d0 c8 02 c0       	push   $0xc002c8d0
c00281b3:	68 b7 01 00 00       	push   $0x1b7
c00281b8:	68 a3 e7 02 c0       	push   $0xc002e7a3
c00281bd:	e8 4d f6 ff ff       	call   c002780f <debug_panic>

c00281c2 <list_insert_ordered>:
   sorted according to LESS given auxiliary data AUX.
   Runs in O(n) average case in the number of elements in LIST. */
void
list_insert_ordered (struct list *list, struct list_elem *elem,
                     list_less_func *less, void *aux)
{
c00281c2:	55                   	push   %ebp
c00281c3:	57                   	push   %edi
c00281c4:	56                   	push   %esi
c00281c5:	53                   	push   %ebx
c00281c6:	83 ec 0c             	sub    $0xc,%esp
c00281c9:	8b 74 24 20          	mov    0x20(%esp),%esi
c00281cd:	8b 7c 24 24          	mov    0x24(%esp),%edi
c00281d1:	8b 6c 24 28          	mov    0x28(%esp),%ebp
  struct list_elem *e;

  ASSERT (list != NULL);
c00281d5:	85 f6                	test   %esi,%esi
c00281d7:	74 50                	je     c0028229 <list_insert_ordered+0x67>
  ASSERT (elem != NULL);
c00281d9:	85 ff                	test   %edi,%edi
c00281db:	74 6d                	je     c002824a <list_insert_ordered+0x88>
  ASSERT (less != NULL);
c00281dd:	85 ed                	test   %ebp,%ebp
c00281df:	0f 84 86 00 00 00    	je     c002826b <list_insert_ordered+0xa9>

  for (e = list_begin (list); e != list_end (list); e = list_next (e))
c00281e5:	83 ec 0c             	sub    $0xc,%esp
c00281e8:	56                   	push   %esi
c00281e9:	e8 0b f7 ff ff       	call   c00278f9 <list_begin>
c00281ee:	83 c4 10             	add    $0x10,%esp
c00281f1:	89 c3                	mov    %eax,%ebx
c00281f3:	83 ec 0c             	sub    $0xc,%esp
c00281f6:	56                   	push   %esi
c00281f7:	e8 75 f7 ff ff       	call   c0027971 <list_end>
c00281fc:	83 c4 10             	add    $0x10,%esp
c00281ff:	39 c3                	cmp    %eax,%ebx
c0028201:	0f 84 85 00 00 00    	je     c002828c <list_insert_ordered+0xca>
    if (less (elem, e, aux))
c0028207:	83 ec 04             	sub    $0x4,%esp
c002820a:	ff 74 24 30          	pushl  0x30(%esp)
c002820e:	53                   	push   %ebx
c002820f:	57                   	push   %edi
c0028210:	ff d5                	call   *%ebp
c0028212:	83 c4 10             	add    $0x10,%esp
c0028215:	84 c0                	test   %al,%al
c0028217:	75 73                	jne    c002828c <list_insert_ordered+0xca>
  for (e = list_begin (list); e != list_end (list); e = list_next (e))
c0028219:	83 ec 0c             	sub    $0xc,%esp
c002821c:	53                   	push   %ebx
c002821d:	e8 07 f7 ff ff       	call   c0027929 <list_next>
c0028222:	83 c4 10             	add    $0x10,%esp
c0028225:	89 c3                	mov    %eax,%ebx
c0028227:	eb ca                	jmp    c00281f3 <list_insert_ordered+0x31>
  ASSERT (list != NULL);
c0028229:	83 ec 0c             	sub    $0xc,%esp
c002822c:	68 96 e7 02 c0       	push   $0xc002e796
c0028231:	68 9f cd 02 c0       	push   $0xc002cd9f
c0028236:	68 9c c8 02 c0       	push   $0xc002c89c
c002823b:	68 c3 01 00 00       	push   $0x1c3
c0028240:	68 a3 e7 02 c0       	push   $0xc002e7a3
c0028245:	e8 c5 f5 ff ff       	call   c002780f <debug_panic>
  ASSERT (elem != NULL);
c002824a:	83 ec 0c             	sub    $0xc,%esp
c002824d:	68 d9 e7 02 c0       	push   $0xc002e7d9
c0028252:	68 9f cd 02 c0       	push   $0xc002cd9f
c0028257:	68 9c c8 02 c0       	push   $0xc002c89c
c002825c:	68 c4 01 00 00       	push   $0x1c4
c0028261:	68 a3 e7 02 c0       	push   $0xc002e7a3
c0028266:	e8 a4 f5 ff ff       	call   c002780f <debug_panic>
  ASSERT (less != NULL);
c002826b:	83 ec 0c             	sub    $0xc,%esp
c002826e:	68 c5 e7 02 c0       	push   $0xc002e7c5
c0028273:	68 9f cd 02 c0       	push   $0xc002cd9f
c0028278:	68 9c c8 02 c0       	push   $0xc002c89c
c002827d:	68 c5 01 00 00       	push   $0x1c5
c0028282:	68 a3 e7 02 c0       	push   $0xc002e7a3
c0028287:	e8 83 f5 ff ff       	call   c002780f <debug_panic>
      break;
  return list_insert (e, elem);
c002828c:	83 ec 08             	sub    $0x8,%esp
c002828f:	57                   	push   %edi
c0028290:	53                   	push   %ebx
c0028291:	e8 47 f9 ff ff       	call   c0027bdd <list_insert>
}
c0028296:	83 c4 1c             	add    $0x1c,%esp
c0028299:	5b                   	pop    %ebx
c002829a:	5e                   	pop    %esi
c002829b:	5f                   	pop    %edi
c002829c:	5d                   	pop    %ebp
c002829d:	c3                   	ret    

c002829e <list_unique>:
   given auxiliary data AUX.  If DUPLICATES is non-null, then the
   elements from LIST are appended to DUPLICATES. */
void
list_unique (struct list *list, struct list *duplicates,
             list_less_func *less, void *aux)
{
c002829e:	55                   	push   %ebp
c002829f:	57                   	push   %edi
c00282a0:	56                   	push   %esi
c00282a1:	53                   	push   %ebx
c00282a2:	83 ec 0c             	sub    $0xc,%esp
c00282a5:	8b 7c 24 20          	mov    0x20(%esp),%edi
c00282a9:	8b 6c 24 28          	mov    0x28(%esp),%ebp
  struct list_elem *elem, *next;

  ASSERT (list != NULL);
c00282ad:	85 ff                	test   %edi,%edi
c00282af:	74 1c                	je     c00282cd <list_unique+0x2f>
  ASSERT (less != NULL);
c00282b1:	85 ed                	test   %ebp,%ebp
c00282b3:	74 39                	je     c00282ee <list_unique+0x50>
  if (list_empty (list))
c00282b5:	83 ec 0c             	sub    $0xc,%esp
c00282b8:	57                   	push   %edi
c00282b9:	e8 3d fb ff ff       	call   c0027dfb <list_empty>
c00282be:	83 c4 10             	add    $0x10,%esp
c00282c1:	84 c0                	test   %al,%al
c00282c3:	74 4a                	je     c002830f <list_unique+0x71>
        if (duplicates != NULL)
          list_push_back (duplicates, next);
      }
    else
      elem = next;
}
c00282c5:	83 c4 0c             	add    $0xc,%esp
c00282c8:	5b                   	pop    %ebx
c00282c9:	5e                   	pop    %esi
c00282ca:	5f                   	pop    %edi
c00282cb:	5d                   	pop    %ebp
c00282cc:	c3                   	ret    
  ASSERT (list != NULL);
c00282cd:	83 ec 0c             	sub    $0xc,%esp
c00282d0:	68 96 e7 02 c0       	push   $0xc002e796
c00282d5:	68 9f cd 02 c0       	push   $0xc002cd9f
c00282da:	68 90 c8 02 c0       	push   $0xc002c890
c00282df:	68 d7 01 00 00       	push   $0x1d7
c00282e4:	68 a3 e7 02 c0       	push   $0xc002e7a3
c00282e9:	e8 21 f5 ff ff       	call   c002780f <debug_panic>
  ASSERT (less != NULL);
c00282ee:	83 ec 0c             	sub    $0xc,%esp
c00282f1:	68 c5 e7 02 c0       	push   $0xc002e7c5
c00282f6:	68 9f cd 02 c0       	push   $0xc002cd9f
c00282fb:	68 90 c8 02 c0       	push   $0xc002c890
c0028300:	68 d8 01 00 00       	push   $0x1d8
c0028305:	68 a3 e7 02 c0       	push   $0xc002e7a3
c002830a:	e8 00 f5 ff ff       	call   c002780f <debug_panic>
  elem = list_begin (list);
c002830f:	83 ec 0c             	sub    $0xc,%esp
c0028312:	57                   	push   %edi
c0028313:	e8 e1 f5 ff ff       	call   c00278f9 <list_begin>
c0028318:	83 c4 10             	add    $0x10,%esp
c002831b:	89 c6                	mov    %eax,%esi
  while ((next = list_next (elem)) != list_end (list))
c002831d:	eb 04                	jmp    c0028323 <list_unique+0x85>
c002831f:	89 f3                	mov    %esi,%ebx
c0028321:	89 de                	mov    %ebx,%esi
c0028323:	83 ec 0c             	sub    $0xc,%esp
c0028326:	56                   	push   %esi
c0028327:	e8 fd f5 ff ff       	call   c0027929 <list_next>
c002832c:	89 c3                	mov    %eax,%ebx
c002832e:	89 3c 24             	mov    %edi,(%esp)
c0028331:	e8 3b f6 ff ff       	call   c0027971 <list_end>
c0028336:	83 c4 10             	add    $0x10,%esp
c0028339:	39 c3                	cmp    %eax,%ebx
c002833b:	74 88                	je     c00282c5 <list_unique+0x27>
    if (!less (elem, next, aux) && !less (next, elem, aux)) 
c002833d:	83 ec 04             	sub    $0x4,%esp
c0028340:	ff 74 24 30          	pushl  0x30(%esp)
c0028344:	53                   	push   %ebx
c0028345:	56                   	push   %esi
c0028346:	ff d5                	call   *%ebp
c0028348:	83 c4 10             	add    $0x10,%esp
c002834b:	84 c0                	test   %al,%al
c002834d:	75 d2                	jne    c0028321 <list_unique+0x83>
c002834f:	83 ec 04             	sub    $0x4,%esp
c0028352:	ff 74 24 30          	pushl  0x30(%esp)
c0028356:	56                   	push   %esi
c0028357:	53                   	push   %ebx
c0028358:	ff d5                	call   *%ebp
c002835a:	83 c4 10             	add    $0x10,%esp
c002835d:	84 c0                	test   %al,%al
c002835f:	75 c0                	jne    c0028321 <list_unique+0x83>
        list_remove (next);
c0028361:	83 ec 0c             	sub    $0xc,%esp
c0028364:	53                   	push   %ebx
c0028365:	e8 06 fa ff ff       	call   c0027d70 <list_remove>
        if (duplicates != NULL)
c002836a:	83 c4 10             	add    $0x10,%esp
c002836d:	83 7c 24 24 00       	cmpl   $0x0,0x24(%esp)
c0028372:	74 ab                	je     c002831f <list_unique+0x81>
          list_push_back (duplicates, next);
c0028374:	83 ec 08             	sub    $0x8,%esp
c0028377:	53                   	push   %ebx
c0028378:	ff 74 24 30          	pushl  0x30(%esp)
c002837c:	e8 d2 f9 ff ff       	call   c0027d53 <list_push_back>
c0028381:	83 c4 10             	add    $0x10,%esp
c0028384:	89 f3                	mov    %esi,%ebx
c0028386:	eb 99                	jmp    c0028321 <list_unique+0x83>

c0028388 <list_max>:
   to LESS given auxiliary data AUX.  If there is more than one
   maximum, returns the one that appears earlier in the list.  If
   the list is empty, returns its tail. */
struct list_elem *
list_max (struct list *list, list_less_func *less, void *aux)
{
c0028388:	55                   	push   %ebp
c0028389:	57                   	push   %edi
c002838a:	56                   	push   %esi
c002838b:	53                   	push   %ebx
c002838c:	83 ec 18             	sub    $0x18,%esp
c002838f:	8b 7c 24 2c          	mov    0x2c(%esp),%edi
c0028393:	8b 6c 24 34          	mov    0x34(%esp),%ebp
  struct list_elem *max = list_begin (list);
c0028397:	57                   	push   %edi
c0028398:	e8 5c f5 ff ff       	call   c00278f9 <list_begin>
c002839d:	89 c6                	mov    %eax,%esi
  if (max != list_end (list)) 
c002839f:	89 3c 24             	mov    %edi,(%esp)
c00283a2:	e8 ca f5 ff ff       	call   c0027971 <list_end>
c00283a7:	83 c4 10             	add    $0x10,%esp
c00283aa:	39 c6                	cmp    %eax,%esi
c00283ac:	74 43                	je     c00283f1 <list_max+0x69>
    {
      struct list_elem *e;
      
      for (e = list_next (max); e != list_end (list); e = list_next (e))
c00283ae:	83 ec 0c             	sub    $0xc,%esp
c00283b1:	56                   	push   %esi
c00283b2:	e8 72 f5 ff ff       	call   c0027929 <list_next>
c00283b7:	83 c4 10             	add    $0x10,%esp
c00283ba:	89 c3                	mov    %eax,%ebx
c00283bc:	eb 0e                	jmp    c00283cc <list_max+0x44>
c00283be:	83 ec 0c             	sub    $0xc,%esp
c00283c1:	53                   	push   %ebx
c00283c2:	e8 62 f5 ff ff       	call   c0027929 <list_next>
c00283c7:	83 c4 10             	add    $0x10,%esp
c00283ca:	89 c3                	mov    %eax,%ebx
c00283cc:	83 ec 0c             	sub    $0xc,%esp
c00283cf:	57                   	push   %edi
c00283d0:	e8 9c f5 ff ff       	call   c0027971 <list_end>
c00283d5:	83 c4 10             	add    $0x10,%esp
c00283d8:	39 c3                	cmp    %eax,%ebx
c00283da:	74 17                	je     c00283f3 <list_max+0x6b>
        if (less (max, e, aux))
c00283dc:	83 ec 04             	sub    $0x4,%esp
c00283df:	55                   	push   %ebp
c00283e0:	53                   	push   %ebx
c00283e1:	56                   	push   %esi
c00283e2:	ff 54 24 34          	call   *0x34(%esp)
c00283e6:	83 c4 10             	add    $0x10,%esp
c00283e9:	84 c0                	test   %al,%al
c00283eb:	74 d1                	je     c00283be <list_max+0x36>
          max = e; 
c00283ed:	89 de                	mov    %ebx,%esi
c00283ef:	eb cd                	jmp    c00283be <list_max+0x36>
  struct list_elem *max = list_begin (list);
c00283f1:	89 c6                	mov    %eax,%esi
    }
  return max;
}
c00283f3:	89 f0                	mov    %esi,%eax
c00283f5:	83 c4 0c             	add    $0xc,%esp
c00283f8:	5b                   	pop    %ebx
c00283f9:	5e                   	pop    %esi
c00283fa:	5f                   	pop    %edi
c00283fb:	5d                   	pop    %ebp
c00283fc:	c3                   	ret    

c00283fd <list_min>:
   to LESS given auxiliary data AUX.  If there is more than one
   minimum, returns the one that appears earlier in the list.  If
   the list is empty, returns its tail. */
struct list_elem *
list_min (struct list *list, list_less_func *less, void *aux)
{
c00283fd:	55                   	push   %ebp
c00283fe:	57                   	push   %edi
c00283ff:	56                   	push   %esi
c0028400:	53                   	push   %ebx
c0028401:	83 ec 18             	sub    $0x18,%esp
c0028404:	8b 7c 24 2c          	mov    0x2c(%esp),%edi
c0028408:	8b 6c 24 34          	mov    0x34(%esp),%ebp
  struct list_elem *min = list_begin (list);
c002840c:	57                   	push   %edi
c002840d:	e8 e7 f4 ff ff       	call   c00278f9 <list_begin>
c0028412:	89 c6                	mov    %eax,%esi
  if (min != list_end (list)) 
c0028414:	89 3c 24             	mov    %edi,(%esp)
c0028417:	e8 55 f5 ff ff       	call   c0027971 <list_end>
c002841c:	83 c4 10             	add    $0x10,%esp
c002841f:	39 c6                	cmp    %eax,%esi
c0028421:	74 43                	je     c0028466 <list_min+0x69>
    {
      struct list_elem *e;
      
      for (e = list_next (min); e != list_end (list); e = list_next (e))
c0028423:	83 ec 0c             	sub    $0xc,%esp
c0028426:	56                   	push   %esi
c0028427:	e8 fd f4 ff ff       	call   c0027929 <list_next>
c002842c:	83 c4 10             	add    $0x10,%esp
c002842f:	89 c3                	mov    %eax,%ebx
c0028431:	eb 0e                	jmp    c0028441 <list_min+0x44>
c0028433:	83 ec 0c             	sub    $0xc,%esp
c0028436:	53                   	push   %ebx
c0028437:	e8 ed f4 ff ff       	call   c0027929 <list_next>
c002843c:	83 c4 10             	add    $0x10,%esp
c002843f:	89 c3                	mov    %eax,%ebx
c0028441:	83 ec 0c             	sub    $0xc,%esp
c0028444:	57                   	push   %edi
c0028445:	e8 27 f5 ff ff       	call   c0027971 <list_end>
c002844a:	83 c4 10             	add    $0x10,%esp
c002844d:	39 c3                	cmp    %eax,%ebx
c002844f:	74 17                	je     c0028468 <list_min+0x6b>
        if (less (e, min, aux))
c0028451:	83 ec 04             	sub    $0x4,%esp
c0028454:	55                   	push   %ebp
c0028455:	56                   	push   %esi
c0028456:	53                   	push   %ebx
c0028457:	ff 54 24 34          	call   *0x34(%esp)
c002845b:	83 c4 10             	add    $0x10,%esp
c002845e:	84 c0                	test   %al,%al
c0028460:	74 d1                	je     c0028433 <list_min+0x36>
          min = e; 
c0028462:	89 de                	mov    %ebx,%esi
c0028464:	eb cd                	jmp    c0028433 <list_min+0x36>
  struct list_elem *min = list_begin (list);
c0028466:	89 c6                	mov    %eax,%esi
    }
  return min;
}
c0028468:	89 f0                	mov    %esi,%eax
c002846a:	83 c4 0c             	add    $0xc,%esp
c002846d:	5b                   	pop    %ebx
c002846e:	5e                   	pop    %esi
c002846f:	5f                   	pop    %edi
c0028470:	5d                   	pop    %ebp
c0028471:	c3                   	ret    

c0028472 <bitmap_buf_size>:

/* Returns the number of elements required for BIT_CNT bits. */
static inline size_t
elem_cnt (size_t bit_cnt)
{
  return DIV_ROUND_UP (bit_cnt, ELEM_BITS);
c0028472:	8b 44 24 04          	mov    0x4(%esp),%eax
c0028476:	83 c0 1f             	add    $0x1f,%eax
c0028479:	c1 e8 05             	shr    $0x5,%eax
/* Returns the number of bytes required to accomodate a bitmap
   with BIT_CNT bits (for use with bitmap_create_in_buf()). */
size_t
bitmap_buf_size (size_t bit_cnt) 
{
  return sizeof (struct bitmap) + byte_cnt (bit_cnt);
c002847c:	8d 04 85 08 00 00 00 	lea    0x8(,%eax,4),%eax
}
c0028483:	c3                   	ret    

c0028484 <bitmap_destroy>:

/* Destroys bitmap B, freeing its storage.
   Not for use on bitmaps created by bitmap_create_in_buf(). */
void
bitmap_destroy (struct bitmap *b) 
{
c0028484:	53                   	push   %ebx
c0028485:	83 ec 08             	sub    $0x8,%esp
c0028488:	8b 5c 24 10          	mov    0x10(%esp),%ebx
  if (b != NULL) 
c002848c:	85 db                	test   %ebx,%ebx
c002848e:	74 16                	je     c00284a6 <bitmap_destroy+0x22>
    {
      free (b->bits);
c0028490:	83 ec 0c             	sub    $0xc,%esp
c0028493:	ff 73 04             	pushl  0x4(%ebx)
c0028496:	e8 88 ab ff ff       	call   c0023023 <free>
      free (b);
c002849b:	89 1c 24             	mov    %ebx,(%esp)
c002849e:	e8 80 ab ff ff       	call   c0023023 <free>
c00284a3:	83 c4 10             	add    $0x10,%esp
    }
}
c00284a6:	83 c4 08             	add    $0x8,%esp
c00284a9:	5b                   	pop    %ebx
c00284aa:	c3                   	ret    

c00284ab <bitmap_size>:

/* Returns the number of bits in B. */
size_t
bitmap_size (const struct bitmap *b)
{
  return b->bit_cnt;
c00284ab:	8b 44 24 04          	mov    0x4(%esp),%eax
c00284af:	8b 00                	mov    (%eax),%eax
}
c00284b1:	c3                   	ret    

c00284b2 <bitmap_mark>:
}

/* Atomically sets the bit numbered BIT_IDX in B to true. */
void
bitmap_mark (struct bitmap *b, size_t bit_idx) 
{
c00284b2:	53                   	push   %ebx
c00284b3:	8b 4c 24 0c          	mov    0xc(%esp),%ecx
  return bit_idx / ELEM_BITS;
c00284b7:	89 cb                	mov    %ecx,%ebx
c00284b9:	c1 eb 05             	shr    $0x5,%ebx
  elem_type mask = bit_mask (bit_idx);

  /* This is equivalent to `b->bits[idx] |= mask' except that it
     is guaranteed to be atomic on a uniprocessor machine.  See
     the description of the OR instruction in [IA32-v2b]. */
  asm ("orl %1, %0" : "=m" (b->bits[idx]) : "r" (mask) : "cc");
c00284bc:	8b 44 24 08          	mov    0x8(%esp),%eax
c00284c0:	8b 50 04             	mov    0x4(%eax),%edx
  return (elem_type) 1 << (bit_idx % ELEM_BITS);
c00284c3:	b8 01 00 00 00       	mov    $0x1,%eax
c00284c8:	d3 e0                	shl    %cl,%eax
  asm ("orl %1, %0" : "=m" (b->bits[idx]) : "r" (mask) : "cc");
c00284ca:	09 04 9a             	or     %eax,(%edx,%ebx,4)
}
c00284cd:	5b                   	pop    %ebx
c00284ce:	c3                   	ret    

c00284cf <bitmap_reset>:

/* Atomically sets the bit numbered BIT_IDX in B to false. */
void
bitmap_reset (struct bitmap *b, size_t bit_idx) 
{
c00284cf:	53                   	push   %ebx
c00284d0:	8b 4c 24 0c          	mov    0xc(%esp),%ecx
  return bit_idx / ELEM_BITS;
c00284d4:	89 cb                	mov    %ecx,%ebx
c00284d6:	c1 eb 05             	shr    $0x5,%ebx
  elem_type mask = bit_mask (bit_idx);

  /* This is equivalent to `b->bits[idx] &= ~mask' except that it
     is guaranteed to be atomic on a uniprocessor machine.  See
     the description of the AND instruction in [IA32-v2a]. */
  asm ("andl %1, %0" : "=m" (b->bits[idx]) : "r" (~mask) : "cc");
c00284d9:	8b 44 24 08          	mov    0x8(%esp),%eax
c00284dd:	8b 50 04             	mov    0x4(%eax),%edx
  return (elem_type) 1 << (bit_idx % ELEM_BITS);
c00284e0:	b8 01 00 00 00       	mov    $0x1,%eax
c00284e5:	d3 e0                	shl    %cl,%eax
  asm ("andl %1, %0" : "=m" (b->bits[idx]) : "r" (~mask) : "cc");
c00284e7:	f7 d0                	not    %eax
c00284e9:	21 04 9a             	and    %eax,(%edx,%ebx,4)
}
c00284ec:	5b                   	pop    %ebx
c00284ed:	c3                   	ret    

c00284ee <bitmap_set>:
{
c00284ee:	83 ec 0c             	sub    $0xc,%esp
c00284f1:	8b 44 24 10          	mov    0x10(%esp),%eax
c00284f5:	8b 54 24 14          	mov    0x14(%esp),%edx
c00284f9:	8b 4c 24 18          	mov    0x18(%esp),%ecx
  ASSERT (b != NULL);
c00284fd:	85 c0                	test   %eax,%eax
c00284ff:	74 19                	je     c002851a <bitmap_set+0x2c>
  ASSERT (idx < b->bit_cnt);
c0028501:	39 10                	cmp    %edx,(%eax)
c0028503:	76 36                	jbe    c002853b <bitmap_set+0x4d>
  if (value)
c0028505:	84 c9                	test   %cl,%cl
c0028507:	75 53                	jne    c002855c <bitmap_set+0x6e>
    bitmap_reset (b, idx);
c0028509:	83 ec 08             	sub    $0x8,%esp
c002850c:	52                   	push   %edx
c002850d:	50                   	push   %eax
c002850e:	e8 bc ff ff ff       	call   c00284cf <bitmap_reset>
c0028513:	83 c4 10             	add    $0x10,%esp
}
c0028516:	83 c4 0c             	add    $0xc,%esp
c0028519:	c3                   	ret    
  ASSERT (b != NULL);
c002851a:	83 ec 0c             	sub    $0xc,%esp
c002851d:	68 bb e7 02 c0       	push   $0xc002e7bb
c0028522:	68 9f cd 02 c0       	push   $0xc002cd9f
c0028527:	68 e0 c9 02 c0       	push   $0xc002c9e0
c002852c:	68 93 00 00 00       	push   $0x93
c0028531:	68 4e e9 02 c0       	push   $0xc002e94e
c0028536:	e8 d4 f2 ff ff       	call   c002780f <debug_panic>
  ASSERT (idx < b->bit_cnt);
c002853b:	83 ec 0c             	sub    $0xc,%esp
c002853e:	68 68 e9 02 c0       	push   $0xc002e968
c0028543:	68 9f cd 02 c0       	push   $0xc002cd9f
c0028548:	68 e0 c9 02 c0       	push   $0xc002c9e0
c002854d:	68 94 00 00 00       	push   $0x94
c0028552:	68 4e e9 02 c0       	push   $0xc002e94e
c0028557:	e8 b3 f2 ff ff       	call   c002780f <debug_panic>
    bitmap_mark (b, idx);
c002855c:	83 ec 08             	sub    $0x8,%esp
c002855f:	52                   	push   %edx
c0028560:	50                   	push   %eax
c0028561:	e8 4c ff ff ff       	call   c00284b2 <bitmap_mark>
c0028566:	83 c4 10             	add    $0x10,%esp
c0028569:	eb ab                	jmp    c0028516 <bitmap_set+0x28>

c002856b <bitmap_flip>:
/* Atomically toggles the bit numbered IDX in B;
   that is, if it is true, makes it false,
   and if it is false, makes it true. */
void
bitmap_flip (struct bitmap *b, size_t bit_idx) 
{
c002856b:	53                   	push   %ebx
c002856c:	8b 4c 24 0c          	mov    0xc(%esp),%ecx
  return bit_idx / ELEM_BITS;
c0028570:	89 cb                	mov    %ecx,%ebx
c0028572:	c1 eb 05             	shr    $0x5,%ebx
  elem_type mask = bit_mask (bit_idx);

  /* This is equivalent to `b->bits[idx] ^= mask' except that it
     is guaranteed to be atomic on a uniprocessor machine.  See
     the description of the XOR instruction in [IA32-v2b]. */
  asm ("xorl %1, %0" : "=m" (b->bits[idx]) : "r" (mask) : "cc");
c0028575:	8b 44 24 08          	mov    0x8(%esp),%eax
c0028579:	8b 50 04             	mov    0x4(%eax),%edx
  return (elem_type) 1 << (bit_idx % ELEM_BITS);
c002857c:	b8 01 00 00 00       	mov    $0x1,%eax
c0028581:	d3 e0                	shl    %cl,%eax
  asm ("xorl %1, %0" : "=m" (b->bits[idx]) : "r" (mask) : "cc");
c0028583:	31 04 9a             	xor    %eax,(%edx,%ebx,4)
}
c0028586:	5b                   	pop    %ebx
c0028587:	c3                   	ret    

c0028588 <bitmap_test>:

/* Returns the value of the bit numbered IDX in B. */
bool
bitmap_test (const struct bitmap *b, size_t idx) 
{
c0028588:	53                   	push   %ebx
c0028589:	83 ec 08             	sub    $0x8,%esp
c002858c:	8b 44 24 10          	mov    0x10(%esp),%eax
c0028590:	8b 4c 24 14          	mov    0x14(%esp),%ecx
  ASSERT (b != NULL);
c0028594:	85 c0                	test   %eax,%eax
c0028596:	74 1e                	je     c00285b6 <bitmap_test+0x2e>
  ASSERT (idx < b->bit_cnt);
c0028598:	39 08                	cmp    %ecx,(%eax)
c002859a:	76 3b                	jbe    c00285d7 <bitmap_test+0x4f>
  return bit_idx / ELEM_BITS;
c002859c:	89 cb                	mov    %ecx,%ebx
c002859e:	c1 eb 05             	shr    $0x5,%ebx
  return (b->bits[elem_idx (idx)] & bit_mask (idx)) != 0;
c00285a1:	8b 50 04             	mov    0x4(%eax),%edx
  return (elem_type) 1 << (bit_idx % ELEM_BITS);
c00285a4:	b8 01 00 00 00       	mov    $0x1,%eax
c00285a9:	d3 e0                	shl    %cl,%eax
  return (b->bits[elem_idx (idx)] & bit_mask (idx)) != 0;
c00285ab:	85 04 9a             	test   %eax,(%edx,%ebx,4)
c00285ae:	0f 95 c0             	setne  %al
}
c00285b1:	83 c4 08             	add    $0x8,%esp
c00285b4:	5b                   	pop    %ebx
c00285b5:	c3                   	ret    
  ASSERT (b != NULL);
c00285b6:	83 ec 0c             	sub    $0xc,%esp
c00285b9:	68 bb e7 02 c0       	push   $0xc002e7bb
c00285be:	68 9f cd 02 c0       	push   $0xc002cd9f
c00285c3:	68 d4 c9 02 c0       	push   $0xc002c9d4
c00285c8:	68 c8 00 00 00       	push   $0xc8
c00285cd:	68 4e e9 02 c0       	push   $0xc002e94e
c00285d2:	e8 38 f2 ff ff       	call   c002780f <debug_panic>
  ASSERT (idx < b->bit_cnt);
c00285d7:	83 ec 0c             	sub    $0xc,%esp
c00285da:	68 68 e9 02 c0       	push   $0xc002e968
c00285df:	68 9f cd 02 c0       	push   $0xc002cd9f
c00285e4:	68 d4 c9 02 c0       	push   $0xc002c9d4
c00285e9:	68 c9 00 00 00       	push   $0xc9
c00285ee:	68 4e e9 02 c0       	push   $0xc002e94e
c00285f3:	e8 17 f2 ff ff       	call   c002780f <debug_panic>

c00285f8 <bitmap_set_multiple>:
}

/* Sets the CNT bits starting at START in B to VALUE. */
void
bitmap_set_multiple (struct bitmap *b, size_t start, size_t cnt, bool value) 
{
c00285f8:	55                   	push   %ebp
c00285f9:	57                   	push   %edi
c00285fa:	56                   	push   %esi
c00285fb:	53                   	push   %ebx
c00285fc:	83 ec 0c             	sub    $0xc,%esp
c00285ff:	8b 74 24 20          	mov    0x20(%esp),%esi
c0028603:	8b 5c 24 24          	mov    0x24(%esp),%ebx
c0028607:	8b 54 24 28          	mov    0x28(%esp),%edx
c002860b:	8a 44 24 2c          	mov    0x2c(%esp),%al
  size_t i;
  
  ASSERT (b != NULL);
c002860f:	85 f6                	test   %esi,%esi
c0028611:	74 2f                	je     c0028642 <bitmap_set_multiple+0x4a>
  ASSERT (start <= b->bit_cnt);
c0028613:	8b 0e                	mov    (%esi),%ecx
c0028615:	39 d9                	cmp    %ebx,%ecx
c0028617:	72 4a                	jb     c0028663 <bitmap_set_multiple+0x6b>
  ASSERT (start + cnt <= b->bit_cnt);
c0028619:	8d 2c 13             	lea    (%ebx,%edx,1),%ebp
c002861c:	39 e9                	cmp    %ebp,%ecx
c002861e:	72 64                	jb     c0028684 <bitmap_set_multiple+0x8c>

  for (i = 0; i < cnt; i++)
c0028620:	85 d2                	test   %edx,%edx
c0028622:	74 16                	je     c002863a <bitmap_set_multiple+0x42>
    bitmap_set (b, start + i, value);
c0028624:	0f b6 f8             	movzbl %al,%edi
c0028627:	83 ec 04             	sub    $0x4,%esp
c002862a:	57                   	push   %edi
c002862b:	53                   	push   %ebx
c002862c:	56                   	push   %esi
c002862d:	e8 bc fe ff ff       	call   c00284ee <bitmap_set>
c0028632:	43                   	inc    %ebx
  for (i = 0; i < cnt; i++)
c0028633:	83 c4 10             	add    $0x10,%esp
c0028636:	39 dd                	cmp    %ebx,%ebp
c0028638:	75 ed                	jne    c0028627 <bitmap_set_multiple+0x2f>
}
c002863a:	83 c4 0c             	add    $0xc,%esp
c002863d:	5b                   	pop    %ebx
c002863e:	5e                   	pop    %esi
c002863f:	5f                   	pop    %edi
c0028640:	5d                   	pop    %ebp
c0028641:	c3                   	ret    
  ASSERT (b != NULL);
c0028642:	83 ec 0c             	sub    $0xc,%esp
c0028645:	68 bb e7 02 c0       	push   $0xc002e7bb
c002864a:	68 9f cd 02 c0       	push   $0xc002cd9f
c002864f:	68 b0 c9 02 c0       	push   $0xc002c9b0
c0028654:	68 de 00 00 00       	push   $0xde
c0028659:	68 4e e9 02 c0       	push   $0xc002e94e
c002865e:	e8 ac f1 ff ff       	call   c002780f <debug_panic>
  ASSERT (start <= b->bit_cnt);
c0028663:	83 ec 0c             	sub    $0xc,%esp
c0028666:	68 79 e9 02 c0       	push   $0xc002e979
c002866b:	68 9f cd 02 c0       	push   $0xc002cd9f
c0028670:	68 b0 c9 02 c0       	push   $0xc002c9b0
c0028675:	68 df 00 00 00       	push   $0xdf
c002867a:	68 4e e9 02 c0       	push   $0xc002e94e
c002867f:	e8 8b f1 ff ff       	call   c002780f <debug_panic>
  ASSERT (start + cnt <= b->bit_cnt);
c0028684:	83 ec 0c             	sub    $0xc,%esp
c0028687:	68 8d e9 02 c0       	push   $0xc002e98d
c002868c:	68 9f cd 02 c0       	push   $0xc002cd9f
c0028691:	68 b0 c9 02 c0       	push   $0xc002c9b0
c0028696:	68 e0 00 00 00       	push   $0xe0
c002869b:	68 4e e9 02 c0       	push   $0xc002e94e
c00286a0:	e8 6a f1 ff ff       	call   c002780f <debug_panic>

c00286a5 <bitmap_set_all>:
{
c00286a5:	83 ec 0c             	sub    $0xc,%esp
c00286a8:	8b 44 24 10          	mov    0x10(%esp),%eax
c00286ac:	8b 54 24 14          	mov    0x14(%esp),%edx
  ASSERT (b != NULL);
c00286b0:	85 c0                	test   %eax,%eax
c00286b2:	74 12                	je     c00286c6 <bitmap_set_all+0x21>
  bitmap_set_multiple (b, 0, bitmap_size (b), value);
c00286b4:	0f b6 d2             	movzbl %dl,%edx
c00286b7:	52                   	push   %edx
c00286b8:	ff 30                	pushl  (%eax)
c00286ba:	6a 00                	push   $0x0
c00286bc:	50                   	push   %eax
c00286bd:	e8 36 ff ff ff       	call   c00285f8 <bitmap_set_multiple>
}
c00286c2:	83 c4 1c             	add    $0x1c,%esp
c00286c5:	c3                   	ret    
  ASSERT (b != NULL);
c00286c6:	83 ec 0c             	sub    $0xc,%esp
c00286c9:	68 bb e7 02 c0       	push   $0xc002e7bb
c00286ce:	68 9f cd 02 c0       	push   $0xc002cd9f
c00286d3:	68 c4 c9 02 c0       	push   $0xc002c9c4
c00286d8:	68 d3 00 00 00       	push   $0xd3
c00286dd:	68 4e e9 02 c0       	push   $0xc002e94e
c00286e2:	e8 28 f1 ff ff       	call   c002780f <debug_panic>

c00286e7 <bitmap_create>:
{
c00286e7:	56                   	push   %esi
c00286e8:	53                   	push   %ebx
c00286e9:	83 ec 10             	sub    $0x10,%esp
c00286ec:	8b 74 24 1c          	mov    0x1c(%esp),%esi
  struct bitmap *b = malloc (sizeof *b);
c00286f0:	6a 08                	push   $0x8
c00286f2:	e8 8b a7 ff ff       	call   c0022e82 <malloc>
c00286f7:	89 c3                	mov    %eax,%ebx
  if (b != NULL)
c00286f9:	83 c4 10             	add    $0x10,%esp
c00286fc:	85 c0                	test   %eax,%eax
c00286fe:	74 2c                	je     c002872c <bitmap_create+0x45>
      b->bit_cnt = bit_cnt;
c0028700:	89 30                	mov    %esi,(%eax)
      b->bits = malloc (byte_cnt (bit_cnt));
c0028702:	83 ec 0c             	sub    $0xc,%esp
  return DIV_ROUND_UP (bit_cnt, ELEM_BITS);
c0028705:	8d 46 1f             	lea    0x1f(%esi),%eax
c0028708:	c1 e8 05             	shr    $0x5,%eax
  return sizeof (elem_type) * elem_cnt (bit_cnt);
c002870b:	c1 e0 02             	shl    $0x2,%eax
      b->bits = malloc (byte_cnt (bit_cnt));
c002870e:	50                   	push   %eax
c002870f:	e8 6e a7 ff ff       	call   c0022e82 <malloc>
c0028714:	89 43 04             	mov    %eax,0x4(%ebx)
      if (b->bits != NULL || bit_cnt == 0)
c0028717:	83 c4 10             	add    $0x10,%esp
c002871a:	85 c0                	test   %eax,%eax
c002871c:	74 16                	je     c0028734 <bitmap_create+0x4d>
          bitmap_set_all (b, false);
c002871e:	83 ec 08             	sub    $0x8,%esp
c0028721:	6a 00                	push   $0x0
c0028723:	53                   	push   %ebx
c0028724:	e8 7c ff ff ff       	call   c00286a5 <bitmap_set_all>
          return b;
c0028729:	83 c4 10             	add    $0x10,%esp
}
c002872c:	89 d8                	mov    %ebx,%eax
c002872e:	83 c4 04             	add    $0x4,%esp
c0028731:	5b                   	pop    %ebx
c0028732:	5e                   	pop    %esi
c0028733:	c3                   	ret    
      if (b->bits != NULL || bit_cnt == 0)
c0028734:	85 f6                	test   %esi,%esi
c0028736:	74 e6                	je     c002871e <bitmap_create+0x37>
      free (b);
c0028738:	83 ec 0c             	sub    $0xc,%esp
c002873b:	53                   	push   %ebx
c002873c:	e8 e2 a8 ff ff       	call   c0023023 <free>
c0028741:	83 c4 10             	add    $0x10,%esp
  return NULL;
c0028744:	bb 00 00 00 00       	mov    $0x0,%ebx
c0028749:	eb e1                	jmp    c002872c <bitmap_create+0x45>

c002874b <bitmap_create_in_buf>:
{
c002874b:	56                   	push   %esi
c002874c:	53                   	push   %ebx
c002874d:	83 ec 04             	sub    $0x4,%esp
c0028750:	8b 74 24 10          	mov    0x10(%esp),%esi
c0028754:	8b 5c 24 14          	mov    0x14(%esp),%ebx
  ASSERT (block_size >= bitmap_buf_size (bit_cnt));
c0028758:	56                   	push   %esi
c0028759:	e8 14 fd ff ff       	call   c0028472 <bitmap_buf_size>
c002875e:	83 c4 04             	add    $0x4,%esp
c0028761:	3b 44 24 18          	cmp    0x18(%esp),%eax
c0028765:	77 1b                	ja     c0028782 <bitmap_create_in_buf+0x37>
  b->bit_cnt = bit_cnt;
c0028767:	89 33                	mov    %esi,(%ebx)
  b->bits = (elem_type *) (b + 1);
c0028769:	8d 43 08             	lea    0x8(%ebx),%eax
c002876c:	89 43 04             	mov    %eax,0x4(%ebx)
  bitmap_set_all (b, false);
c002876f:	83 ec 08             	sub    $0x8,%esp
c0028772:	6a 00                	push   $0x0
c0028774:	53                   	push   %ebx
c0028775:	e8 2b ff ff ff       	call   c00286a5 <bitmap_set_all>
}
c002877a:	89 d8                	mov    %ebx,%eax
c002877c:	83 c4 14             	add    $0x14,%esp
c002877f:	5b                   	pop    %ebx
c0028780:	5e                   	pop    %esi
c0028781:	c3                   	ret    
  ASSERT (block_size >= bitmap_buf_size (bit_cnt));
c0028782:	83 ec 0c             	sub    $0xc,%esp
c0028785:	68 a8 e9 02 c0       	push   $0xc002e9a8
c002878a:	68 9f cd 02 c0       	push   $0xc002cd9f
c002878f:	68 ec c9 02 c0       	push   $0xc002c9ec
c0028794:	6a 68                	push   $0x68
c0028796:	68 4e e9 02 c0       	push   $0xc002e94e
c002879b:	e8 6f f0 ff ff       	call   c002780f <debug_panic>

c00287a0 <bitmap_count>:

/* Returns the number of bits in B between START and START + CNT,
   exclusive, that are set to VALUE. */
size_t
bitmap_count (const struct bitmap *b, size_t start, size_t cnt, bool value) 
{
c00287a0:	55                   	push   %ebp
c00287a1:	57                   	push   %edi
c00287a2:	56                   	push   %esi
c00287a3:	53                   	push   %ebx
c00287a4:	83 ec 1c             	sub    $0x1c,%esp
c00287a7:	8b 7c 24 30          	mov    0x30(%esp),%edi
c00287ab:	8b 74 24 34          	mov    0x34(%esp),%esi
c00287af:	8b 44 24 38          	mov    0x38(%esp),%eax
c00287b3:	8a 5c 24 3c          	mov    0x3c(%esp),%bl
  size_t i, value_cnt;

  ASSERT (b != NULL);
c00287b7:	85 ff                	test   %edi,%edi
c00287b9:	74 29                	je     c00287e4 <bitmap_count+0x44>
  ASSERT (start <= b->bit_cnt);
c00287bb:	8b 17                	mov    (%edi),%edx
c00287bd:	39 f2                	cmp    %esi,%edx
c00287bf:	72 44                	jb     c0028805 <bitmap_count+0x65>
  ASSERT (start + cnt <= b->bit_cnt);
c00287c1:	8d 2c 06             	lea    (%esi,%eax,1),%ebp
c00287c4:	39 ea                	cmp    %ebp,%edx
c00287c6:	72 5e                	jb     c0028826 <bitmap_count+0x86>

  value_cnt = 0;
  for (i = 0; i < cnt; i++)
c00287c8:	c7 44 24 0c 00 00 00 	movl   $0x0,0xc(%esp)
c00287cf:	00 
c00287d0:	85 c0                	test   %eax,%eax
c00287d2:	75 78                	jne    c002884c <bitmap_count+0xac>
c00287d4:	89 44 24 0c          	mov    %eax,0xc(%esp)
    if (bitmap_test (b, start + i) == value)
      value_cnt++;
  return value_cnt;
}
c00287d8:	8b 44 24 0c          	mov    0xc(%esp),%eax
c00287dc:	83 c4 1c             	add    $0x1c,%esp
c00287df:	5b                   	pop    %ebx
c00287e0:	5e                   	pop    %esi
c00287e1:	5f                   	pop    %edi
c00287e2:	5d                   	pop    %ebp
c00287e3:	c3                   	ret    
  ASSERT (b != NULL);
c00287e4:	83 ec 0c             	sub    $0xc,%esp
c00287e7:	68 bb e7 02 c0       	push   $0xc002e7bb
c00287ec:	68 9f cd 02 c0       	push   $0xc002cd9f
c00287f1:	68 a0 c9 02 c0       	push   $0xc002c9a0
c00287f6:	68 ed 00 00 00       	push   $0xed
c00287fb:	68 4e e9 02 c0       	push   $0xc002e94e
c0028800:	e8 0a f0 ff ff       	call   c002780f <debug_panic>
  ASSERT (start <= b->bit_cnt);
c0028805:	83 ec 0c             	sub    $0xc,%esp
c0028808:	68 79 e9 02 c0       	push   $0xc002e979
c002880d:	68 9f cd 02 c0       	push   $0xc002cd9f
c0028812:	68 a0 c9 02 c0       	push   $0xc002c9a0
c0028817:	68 ee 00 00 00       	push   $0xee
c002881c:	68 4e e9 02 c0       	push   $0xc002e94e
c0028821:	e8 e9 ef ff ff       	call   c002780f <debug_panic>
  ASSERT (start + cnt <= b->bit_cnt);
c0028826:	83 ec 0c             	sub    $0xc,%esp
c0028829:	68 8d e9 02 c0       	push   $0xc002e98d
c002882e:	68 9f cd 02 c0       	push   $0xc002cd9f
c0028833:	68 a0 c9 02 c0       	push   $0xc002c9a0
c0028838:	68 ef 00 00 00       	push   $0xef
c002883d:	68 4e e9 02 c0       	push   $0xc002e94e
c0028842:	e8 c8 ef ff ff       	call   c002780f <debug_panic>
c0028847:	46                   	inc    %esi
  for (i = 0; i < cnt; i++)
c0028848:	39 f5                	cmp    %esi,%ebp
c002884a:	74 8c                	je     c00287d8 <bitmap_count+0x38>
    if (bitmap_test (b, start + i) == value)
c002884c:	83 ec 08             	sub    $0x8,%esp
c002884f:	56                   	push   %esi
c0028850:	57                   	push   %edi
c0028851:	e8 32 fd ff ff       	call   c0028588 <bitmap_test>
c0028856:	83 c4 10             	add    $0x10,%esp
c0028859:	38 d8                	cmp    %bl,%al
c002885b:	75 ea                	jne    c0028847 <bitmap_count+0xa7>
      value_cnt++;
c002885d:	ff 44 24 0c          	incl   0xc(%esp)
c0028861:	eb e4                	jmp    c0028847 <bitmap_count+0xa7>

c0028863 <bitmap_contains>:

/* Returns true if any bits in B between START and START + CNT,
   exclusive, are set to VALUE, and false otherwise. */
bool
bitmap_contains (const struct bitmap *b, size_t start, size_t cnt, bool value) 
{
c0028863:	55                   	push   %ebp
c0028864:	57                   	push   %edi
c0028865:	56                   	push   %esi
c0028866:	53                   	push   %ebx
c0028867:	83 ec 0c             	sub    $0xc,%esp
c002886a:	8b 7c 24 20          	mov    0x20(%esp),%edi
c002886e:	8b 74 24 24          	mov    0x24(%esp),%esi
c0028872:	8b 44 24 28          	mov    0x28(%esp),%eax
c0028876:	8a 5c 24 2c          	mov    0x2c(%esp),%bl
  size_t i;
  
  ASSERT (b != NULL);
c002887a:	85 ff                	test   %edi,%edi
c002887c:	74 2b                	je     c00288a9 <bitmap_contains+0x46>
  ASSERT (start <= b->bit_cnt);
c002887e:	8b 17                	mov    (%edi),%edx
c0028880:	39 f2                	cmp    %esi,%edx
c0028882:	72 46                	jb     c00288ca <bitmap_contains+0x67>
  ASSERT (start + cnt <= b->bit_cnt);
c0028884:	8d 2c 06             	lea    (%esi,%eax,1),%ebp
c0028887:	39 ea                	cmp    %ebp,%edx
c0028889:	72 60                	jb     c00288eb <bitmap_contains+0x88>

  for (i = 0; i < cnt; i++)
c002888b:	85 c0                	test   %eax,%eax
c002888d:	74 7f                	je     c002890e <bitmap_contains+0xab>
    if (bitmap_test (b, start + i) == value)
c002888f:	83 ec 08             	sub    $0x8,%esp
c0028892:	56                   	push   %esi
c0028893:	57                   	push   %edi
c0028894:	e8 ef fc ff ff       	call   c0028588 <bitmap_test>
c0028899:	83 c4 10             	add    $0x10,%esp
c002889c:	38 d8                	cmp    %bl,%al
c002889e:	74 6c                	je     c002890c <bitmap_contains+0xa9>
c00288a0:	46                   	inc    %esi
  for (i = 0; i < cnt; i++)
c00288a1:	39 f5                	cmp    %esi,%ebp
c00288a3:	75 ea                	jne    c002888f <bitmap_contains+0x2c>
      return true;
  return false;
c00288a5:	b0 00                	mov    $0x0,%al
c00288a7:	eb 65                	jmp    c002890e <bitmap_contains+0xab>
  ASSERT (b != NULL);
c00288a9:	83 ec 0c             	sub    $0xc,%esp
c00288ac:	68 bb e7 02 c0       	push   $0xc002e7bb
c00288b1:	68 9f cd 02 c0       	push   $0xc002cd9f
c00288b6:	68 90 c9 02 c0       	push   $0xc002c990
c00288bb:	68 ff 00 00 00       	push   $0xff
c00288c0:	68 4e e9 02 c0       	push   $0xc002e94e
c00288c5:	e8 45 ef ff ff       	call   c002780f <debug_panic>
  ASSERT (start <= b->bit_cnt);
c00288ca:	83 ec 0c             	sub    $0xc,%esp
c00288cd:	68 79 e9 02 c0       	push   $0xc002e979
c00288d2:	68 9f cd 02 c0       	push   $0xc002cd9f
c00288d7:	68 90 c9 02 c0       	push   $0xc002c990
c00288dc:	68 00 01 00 00       	push   $0x100
c00288e1:	68 4e e9 02 c0       	push   $0xc002e94e
c00288e6:	e8 24 ef ff ff       	call   c002780f <debug_panic>
  ASSERT (start + cnt <= b->bit_cnt);
c00288eb:	83 ec 0c             	sub    $0xc,%esp
c00288ee:	68 8d e9 02 c0       	push   $0xc002e98d
c00288f3:	68 9f cd 02 c0       	push   $0xc002cd9f
c00288f8:	68 90 c9 02 c0       	push   $0xc002c990
c00288fd:	68 01 01 00 00       	push   $0x101
c0028902:	68 4e e9 02 c0       	push   $0xc002e94e
c0028907:	e8 03 ef ff ff       	call   c002780f <debug_panic>
      return true;
c002890c:	b0 01                	mov    $0x1,%al
}
c002890e:	83 c4 0c             	add    $0xc,%esp
c0028911:	5b                   	pop    %ebx
c0028912:	5e                   	pop    %esi
c0028913:	5f                   	pop    %edi
c0028914:	5d                   	pop    %ebp
c0028915:	c3                   	ret    

c0028916 <bitmap_any>:

/* Returns true if any bits in B between START and START + CNT,
   exclusive, are set to true, and false otherwise.*/
bool
bitmap_any (const struct bitmap *b, size_t start, size_t cnt) 
{
c0028916:	83 ec 0c             	sub    $0xc,%esp
  return bitmap_contains (b, start, cnt, true);
c0028919:	6a 01                	push   $0x1
c002891b:	ff 74 24 1c          	pushl  0x1c(%esp)
c002891f:	ff 74 24 1c          	pushl  0x1c(%esp)
c0028923:	ff 74 24 1c          	pushl  0x1c(%esp)
c0028927:	e8 37 ff ff ff       	call   c0028863 <bitmap_contains>
}
c002892c:	83 c4 1c             	add    $0x1c,%esp
c002892f:	c3                   	ret    

c0028930 <bitmap_none>:

/* Returns true if no bits in B between START and START + CNT,
   exclusive, are set to true, and false otherwise.*/
bool
bitmap_none (const struct bitmap *b, size_t start, size_t cnt) 
{
c0028930:	83 ec 0c             	sub    $0xc,%esp
  return !bitmap_contains (b, start, cnt, true);
c0028933:	6a 01                	push   $0x1
c0028935:	ff 74 24 1c          	pushl  0x1c(%esp)
c0028939:	ff 74 24 1c          	pushl  0x1c(%esp)
c002893d:	ff 74 24 1c          	pushl  0x1c(%esp)
c0028941:	e8 1d ff ff ff       	call   c0028863 <bitmap_contains>
c0028946:	83 f0 01             	xor    $0x1,%eax
}
c0028949:	83 c4 1c             	add    $0x1c,%esp
c002894c:	c3                   	ret    

c002894d <bitmap_all>:

/* Returns true if every bit in B between START and START + CNT,
   exclusive, is set to true, and false otherwise. */
bool
bitmap_all (const struct bitmap *b, size_t start, size_t cnt) 
{
c002894d:	83 ec 0c             	sub    $0xc,%esp
  return !bitmap_contains (b, start, cnt, false);
c0028950:	6a 00                	push   $0x0
c0028952:	ff 74 24 1c          	pushl  0x1c(%esp)
c0028956:	ff 74 24 1c          	pushl  0x1c(%esp)
c002895a:	ff 74 24 1c          	pushl  0x1c(%esp)
c002895e:	e8 00 ff ff ff       	call   c0028863 <bitmap_contains>
c0028963:	83 f0 01             	xor    $0x1,%eax
}
c0028966:	83 c4 1c             	add    $0x1c,%esp
c0028969:	c3                   	ret    

c002896a <bitmap_scan>:
   consecutive bits in B at or after START that are all set to
   VALUE.
   If there is no such group, returns BITMAP_ERROR. */
size_t
bitmap_scan (const struct bitmap *b, size_t start, size_t cnt, bool value) 
{
c002896a:	55                   	push   %ebp
c002896b:	57                   	push   %edi
c002896c:	56                   	push   %esi
c002896d:	53                   	push   %ebx
c002896e:	83 ec 1c             	sub    $0x1c,%esp
c0028971:	8b 74 24 30          	mov    0x30(%esp),%esi
c0028975:	8b 5c 24 34          	mov    0x34(%esp),%ebx
c0028979:	8b 7c 24 38          	mov    0x38(%esp),%edi
c002897d:	8a 54 24 3c          	mov    0x3c(%esp),%dl
  ASSERT (b != NULL);
c0028981:	85 f6                	test   %esi,%esi
c0028983:	74 17                	je     c002899c <bitmap_scan+0x32>
  ASSERT (start <= b->bit_cnt);
c0028985:	8b 06                	mov    (%esi),%eax
c0028987:	39 d8                	cmp    %ebx,%eax
c0028989:	72 32                	jb     c00289bd <bitmap_scan+0x53>

  if (cnt <= b->bit_cnt) 
c002898b:	39 f8                	cmp    %edi,%eax
c002898d:	73 4f                	jae    c00289de <bitmap_scan+0x74>
      size_t i;
      for (i = start; i <= last; i++)
        if (!bitmap_contains (b, i, cnt, !value))
          return i; 
    }
  return BITMAP_ERROR;
c002898f:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
}
c0028994:	83 c4 1c             	add    $0x1c,%esp
c0028997:	5b                   	pop    %ebx
c0028998:	5e                   	pop    %esi
c0028999:	5f                   	pop    %edi
c002899a:	5d                   	pop    %ebp
c002899b:	c3                   	ret    
  ASSERT (b != NULL);
c002899c:	83 ec 0c             	sub    $0xc,%esp
c002899f:	68 bb e7 02 c0       	push   $0xc002e7bb
c00289a4:	68 9f cd 02 c0       	push   $0xc002cd9f
c00289a9:	68 84 c9 02 c0       	push   $0xc002c984
c00289ae:	68 2a 01 00 00       	push   $0x12a
c00289b3:	68 4e e9 02 c0       	push   $0xc002e94e
c00289b8:	e8 52 ee ff ff       	call   c002780f <debug_panic>
  ASSERT (start <= b->bit_cnt);
c00289bd:	83 ec 0c             	sub    $0xc,%esp
c00289c0:	68 79 e9 02 c0       	push   $0xc002e979
c00289c5:	68 9f cd 02 c0       	push   $0xc002cd9f
c00289ca:	68 84 c9 02 c0       	push   $0xc002c984
c00289cf:	68 2b 01 00 00       	push   $0x12b
c00289d4:	68 4e e9 02 c0       	push   $0xc002e94e
c00289d9:	e8 31 ee ff ff       	call   c002780f <debug_panic>
      size_t last = b->bit_cnt - cnt;
c00289de:	29 f8                	sub    %edi,%eax
c00289e0:	89 44 24 0c          	mov    %eax,0xc(%esp)
      for (i = start; i <= last; i++)
c00289e4:	39 c3                	cmp    %eax,%ebx
c00289e6:	77 24                	ja     c0028a0c <bitmap_scan+0xa2>
        if (!bitmap_contains (b, i, cnt, !value))
c00289e8:	83 f2 01             	xor    $0x1,%edx
c00289eb:	0f b6 ea             	movzbl %dl,%ebp
c00289ee:	55                   	push   %ebp
c00289ef:	57                   	push   %edi
c00289f0:	53                   	push   %ebx
c00289f1:	56                   	push   %esi
c00289f2:	e8 6c fe ff ff       	call   c0028863 <bitmap_contains>
c00289f7:	83 c4 10             	add    $0x10,%esp
c00289fa:	84 c0                	test   %al,%al
c00289fc:	74 15                	je     c0028a13 <bitmap_scan+0xa9>
      for (i = start; i <= last; i++)
c00289fe:	43                   	inc    %ebx
c00289ff:	39 5c 24 0c          	cmp    %ebx,0xc(%esp)
c0028a03:	73 e9                	jae    c00289ee <bitmap_scan+0x84>
  return BITMAP_ERROR;
c0028a05:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
c0028a0a:	eb 88                	jmp    c0028994 <bitmap_scan+0x2a>
c0028a0c:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
c0028a11:	eb 81                	jmp    c0028994 <bitmap_scan+0x2a>
c0028a13:	89 d8                	mov    %ebx,%eax
c0028a15:	e9 7a ff ff ff       	jmp    c0028994 <bitmap_scan+0x2a>

c0028a1a <bitmap_scan_and_flip>:
   If CNT is zero, returns 0.
   Bits are set atomically, but testing bits is not atomic with
   setting them. */
size_t
bitmap_scan_and_flip (struct bitmap *b, size_t start, size_t cnt, bool value)
{
c0028a1a:	55                   	push   %ebp
c0028a1b:	57                   	push   %edi
c0028a1c:	56                   	push   %esi
c0028a1d:	53                   	push   %ebx
c0028a1e:	83 ec 0c             	sub    $0xc,%esp
c0028a21:	8b 7c 24 20          	mov    0x20(%esp),%edi
c0028a25:	8b 6c 24 28          	mov    0x28(%esp),%ebp
c0028a29:	8b 5c 24 2c          	mov    0x2c(%esp),%ebx
  size_t idx = bitmap_scan (b, start, cnt, value);
c0028a2d:	0f b6 c3             	movzbl %bl,%eax
c0028a30:	50                   	push   %eax
c0028a31:	55                   	push   %ebp
c0028a32:	ff 74 24 2c          	pushl  0x2c(%esp)
c0028a36:	57                   	push   %edi
c0028a37:	e8 2e ff ff ff       	call   c002896a <bitmap_scan>
c0028a3c:	83 c4 10             	add    $0x10,%esp
c0028a3f:	89 c6                	mov    %eax,%esi
  if (idx != BITMAP_ERROR) 
c0028a41:	83 f8 ff             	cmp    $0xffffffff,%eax
c0028a44:	74 12                	je     c0028a58 <bitmap_scan_and_flip+0x3e>
    bitmap_set_multiple (b, idx, cnt, !value);
c0028a46:	83 f3 01             	xor    $0x1,%ebx
c0028a49:	0f b6 db             	movzbl %bl,%ebx
c0028a4c:	53                   	push   %ebx
c0028a4d:	55                   	push   %ebp
c0028a4e:	50                   	push   %eax
c0028a4f:	57                   	push   %edi
c0028a50:	e8 a3 fb ff ff       	call   c00285f8 <bitmap_set_multiple>
c0028a55:	83 c4 10             	add    $0x10,%esp
  return idx;
}
c0028a58:	89 f0                	mov    %esi,%eax
c0028a5a:	83 c4 0c             	add    $0xc,%esp
c0028a5d:	5b                   	pop    %ebx
c0028a5e:	5e                   	pop    %esi
c0028a5f:	5f                   	pop    %edi
c0028a60:	5d                   	pop    %ebp
c0028a61:	c3                   	ret    

c0028a62 <bitmap_dump>:
/* Debugging. */

/* Dumps the contents of B to the console as hexadecimal. */
void
bitmap_dump (const struct bitmap *b) 
{
c0028a62:	83 ec 0c             	sub    $0xc,%esp
c0028a65:	8b 54 24 10          	mov    0x10(%esp),%edx
  hex_dump (0, b->bits, byte_cnt (b->bit_cnt), false);
c0028a69:	6a 00                	push   $0x0
  return DIV_ROUND_UP (bit_cnt, ELEM_BITS);
c0028a6b:	8b 02                	mov    (%edx),%eax
c0028a6d:	83 c0 1f             	add    $0x1f,%eax
c0028a70:	c1 e8 05             	shr    $0x5,%eax
  return sizeof (elem_type) * elem_cnt (bit_cnt);
c0028a73:	c1 e0 02             	shl    $0x2,%eax
  hex_dump (0, b->bits, byte_cnt (b->bit_cnt), false);
c0028a76:	50                   	push   %eax
c0028a77:	ff 72 04             	pushl  0x4(%edx)
c0028a7a:	6a 00                	push   $0x0
c0028a7c:	e8 89 da ff ff       	call   c002650a <hex_dump>
}
c0028a81:	83 c4 1c             	add    $0x1c,%esp
c0028a84:	c3                   	ret    

c0028a85 <find_bucket>:
}

/* Returns the bucket in H that E belongs in. */
static struct list *
find_bucket (struct hash *h, struct hash_elem *e) 
{
c0028a85:	53                   	push   %ebx
c0028a86:	83 ec 10             	sub    $0x10,%esp
c0028a89:	89 c3                	mov    %eax,%ebx
  size_t bucket_idx = h->hash (e, h->aux) & (h->bucket_cnt - 1);
c0028a8b:	ff 70 14             	pushl  0x14(%eax)
c0028a8e:	52                   	push   %edx
c0028a8f:	ff 50 0c             	call   *0xc(%eax)
c0028a92:	8b 4b 04             	mov    0x4(%ebx),%ecx
c0028a95:	8d 51 ff             	lea    -0x1(%ecx),%edx
c0028a98:	21 d0                	and    %edx,%eax
  return &h->buckets[bucket_idx];
c0028a9a:	c1 e0 04             	shl    $0x4,%eax
c0028a9d:	03 43 08             	add    0x8(%ebx),%eax
}
c0028aa0:	83 c4 18             	add    $0x18,%esp
c0028aa3:	5b                   	pop    %ebx
c0028aa4:	c3                   	ret    

c0028aa5 <find_elem>:

/* Searches BUCKET in H for a hash element equal to E.  Returns
   it if found or a null pointer otherwise. */
static struct hash_elem *
find_elem (struct hash *h, struct list *bucket, struct hash_elem *e) 
{
c0028aa5:	55                   	push   %ebp
c0028aa6:	57                   	push   %edi
c0028aa7:	56                   	push   %esi
c0028aa8:	53                   	push   %ebx
c0028aa9:	83 ec 18             	sub    $0x18,%esp
c0028aac:	89 c6                	mov    %eax,%esi
c0028aae:	89 d5                	mov    %edx,%ebp
c0028ab0:	89 cf                	mov    %ecx,%edi
  struct list_elem *i;

  for (i = list_begin (bucket); i != list_end (bucket); i = list_next (i)) 
c0028ab2:	52                   	push   %edx
c0028ab3:	e8 41 ee ff ff       	call   c00278f9 <list_begin>
c0028ab8:	89 c3                	mov    %eax,%ebx
c0028aba:	83 c4 10             	add    $0x10,%esp
c0028abd:	eb 0e                	jmp    c0028acd <find_elem+0x28>
c0028abf:	83 ec 0c             	sub    $0xc,%esp
c0028ac2:	53                   	push   %ebx
c0028ac3:	e8 61 ee ff ff       	call   c0027929 <list_next>
c0028ac8:	89 c3                	mov    %eax,%ebx
c0028aca:	83 c4 10             	add    $0x10,%esp
c0028acd:	83 ec 0c             	sub    $0xc,%esp
c0028ad0:	55                   	push   %ebp
c0028ad1:	e8 9b ee ff ff       	call   c0027971 <list_end>
c0028ad6:	83 c4 10             	add    $0x10,%esp
c0028ad9:	39 c3                	cmp    %eax,%ebx
c0028adb:	74 28                	je     c0028b05 <find_elem+0x60>
    {
      struct hash_elem *hi = list_elem_to_hash_elem (i);
      if (!h->less (hi, e, h->aux) && !h->less (e, hi, h->aux))
c0028add:	83 ec 04             	sub    $0x4,%esp
c0028ae0:	ff 76 14             	pushl  0x14(%esi)
c0028ae3:	57                   	push   %edi
c0028ae4:	53                   	push   %ebx
c0028ae5:	ff 56 10             	call   *0x10(%esi)
c0028ae8:	83 c4 10             	add    $0x10,%esp
c0028aeb:	84 c0                	test   %al,%al
c0028aed:	75 d0                	jne    c0028abf <find_elem+0x1a>
c0028aef:	83 ec 04             	sub    $0x4,%esp
c0028af2:	ff 76 14             	pushl  0x14(%esi)
c0028af5:	53                   	push   %ebx
c0028af6:	57                   	push   %edi
c0028af7:	ff 56 10             	call   *0x10(%esi)
c0028afa:	83 c4 10             	add    $0x10,%esp
c0028afd:	84 c0                	test   %al,%al
c0028aff:	75 be                	jne    c0028abf <find_elem+0x1a>
c0028b01:	89 d8                	mov    %ebx,%eax
c0028b03:	eb 05                	jmp    c0028b0a <find_elem+0x65>
        return hi; 
    }
  return NULL;
c0028b05:	b8 00 00 00 00       	mov    $0x0,%eax
}
c0028b0a:	83 c4 0c             	add    $0xc,%esp
c0028b0d:	5b                   	pop    %ebx
c0028b0e:	5e                   	pop    %esi
c0028b0f:	5f                   	pop    %edi
c0028b10:	5d                   	pop    %ebp
c0028b11:	c3                   	ret    

c0028b12 <rehash>:
   ideal.  This function can fail because of an out-of-memory
   condition, but that'll just make hash accesses less efficient;
   we can still continue. */
static void
rehash (struct hash *h) 
{
c0028b12:	55                   	push   %ebp
c0028b13:	57                   	push   %edi
c0028b14:	56                   	push   %esi
c0028b15:	53                   	push   %ebx
c0028b16:	83 ec 2c             	sub    $0x2c,%esp
c0028b19:	89 44 24 0c          	mov    %eax,0xc(%esp)
  size_t old_bucket_cnt, new_bucket_cnt;
  struct list *new_buckets, *old_buckets;
  size_t i;

  ASSERT (h != NULL);
c0028b1d:	85 c0                	test   %eax,%eax
c0028b1f:	74 21                	je     c0028b42 <rehash+0x30>

  /* Save old bucket info for later use. */
  old_buckets = h->buckets;
  old_bucket_cnt = h->bucket_cnt;
c0028b21:	8b 44 24 0c          	mov    0xc(%esp),%eax
c0028b25:	8b 48 04             	mov    0x4(%eax),%ecx
c0028b28:	89 4c 24 18          	mov    %ecx,0x18(%esp)

  /* Calculate the number of buckets to use now.
     We want one bucket for about every BEST_ELEMS_PER_BUCKET.
     We must have at least four buckets, and the number of
     buckets must be a power of 2. */
  new_bucket_cnt = h->elem_cnt / BEST_ELEMS_PER_BUCKET;
c0028b2c:	8b 00                	mov    (%eax),%eax
c0028b2e:	89 44 24 10          	mov    %eax,0x10(%esp)
c0028b32:	89 c3                	mov    %eax,%ebx
c0028b34:	d1 eb                	shr    %ebx
c0028b36:	83 fb 04             	cmp    $0x4,%ebx
c0028b39:	73 2d                	jae    c0028b68 <rehash+0x56>
c0028b3b:	bb 04 00 00 00       	mov    $0x4,%ebx
c0028b40:	eb 26                	jmp    c0028b68 <rehash+0x56>
  ASSERT (h != NULL);
c0028b42:	83 ec 0c             	sub    $0xc,%esp
c0028b45:	68 d0 e9 02 c0       	push   $0xc002e9d0
c0028b4a:	68 9f cd 02 c0       	push   $0xc002cd9f
c0028b4f:	68 40 ca 02 c0       	push   $0xc002ca40
c0028b54:	68 66 01 00 00       	push   $0x166
c0028b59:	68 da e9 02 c0       	push   $0xc002e9da
c0028b5e:	e8 ac ec ff ff       	call   c002780f <debug_panic>
  return x & (x - 1);
c0028b63:	8d 43 ff             	lea    -0x1(%ebx),%eax
c0028b66:	21 c3                	and    %eax,%ebx
  return x != 0 && turn_off_least_1bit (x) == 0;
c0028b68:	85 db                	test   %ebx,%ebx
c0028b6a:	74 f7                	je     c0028b63 <rehash+0x51>
  return x & (x - 1);
c0028b6c:	8d 43 ff             	lea    -0x1(%ebx),%eax
  if (new_bucket_cnt < 4)
    new_bucket_cnt = 4;
  while (!is_power_of_2 (new_bucket_cnt))
c0028b6f:	21 d8                	and    %ebx,%eax
c0028b71:	75 f0                	jne    c0028b63 <rehash+0x51>
c0028b73:	89 c6                	mov    %eax,%esi
c0028b75:	89 44 24 10          	mov    %eax,0x10(%esp)
    new_bucket_cnt = turn_off_least_1bit (new_bucket_cnt);

  /* Don't do anything if the bucket count wouldn't change. */
  if (new_bucket_cnt == old_bucket_cnt)
c0028b79:	3b 5c 24 18          	cmp    0x18(%esp),%ebx
c0028b7d:	0f 84 ce 00 00 00    	je     c0028c51 <rehash+0x13f>
  old_buckets = h->buckets;
c0028b83:	8b 44 24 0c          	mov    0xc(%esp),%eax
c0028b87:	8b 40 08             	mov    0x8(%eax),%eax
c0028b8a:	89 44 24 1c          	mov    %eax,0x1c(%esp)
    return;

  /* Allocate new buckets and initialize them as empty. */
  new_buckets = malloc (sizeof *new_buckets * new_bucket_cnt);
c0028b8e:	83 ec 0c             	sub    $0xc,%esp
c0028b91:	89 d8                	mov    %ebx,%eax
c0028b93:	c1 e0 04             	shl    $0x4,%eax
c0028b96:	50                   	push   %eax
c0028b97:	e8 e6 a2 ff ff       	call   c0022e82 <malloc>
c0028b9c:	89 c5                	mov    %eax,%ebp
  if (new_buckets == NULL) 
c0028b9e:	83 c4 10             	add    $0x10,%esp
c0028ba1:	85 c0                	test   %eax,%eax
c0028ba3:	0f 84 a8 00 00 00    	je     c0028c51 <rehash+0x13f>
c0028ba9:	89 c7                	mov    %eax,%edi
         be less efficient.  However, it is still usable, so
         there's no reason for it to be an error. */
      return;
    }
  for (i = 0; i < new_bucket_cnt; i++) 
    list_init (&new_buckets[i]);
c0028bab:	83 ec 0c             	sub    $0xc,%esp
c0028bae:	57                   	push   %edi
c0028baf:	e8 02 ed ff ff       	call   c00278b6 <list_init>
  for (i = 0; i < new_bucket_cnt; i++) 
c0028bb4:	46                   	inc    %esi
c0028bb5:	83 c7 10             	add    $0x10,%edi
c0028bb8:	83 c4 10             	add    $0x10,%esp
c0028bbb:	39 f3                	cmp    %esi,%ebx
c0028bbd:	75 ec                	jne    c0028bab <rehash+0x99>

  /* Install new bucket info. */
  h->buckets = new_buckets;
c0028bbf:	8b 44 24 0c          	mov    0xc(%esp),%eax
c0028bc3:	89 68 08             	mov    %ebp,0x8(%eax)
  h->bucket_cnt = new_bucket_cnt;
c0028bc6:	89 58 04             	mov    %ebx,0x4(%eax)

  /* Move each old element into the appropriate new bucket. */
  for (i = 0; i < old_bucket_cnt; i++) 
c0028bc9:	83 7c 24 18 00       	cmpl   $0x0,0x18(%esp)
c0028bce:	74 72                	je     c0028c42 <rehash+0x130>
c0028bd0:	8b 44 24 1c          	mov    0x1c(%esp),%eax
c0028bd4:	89 44 24 14          	mov    %eax,0x14(%esp)
c0028bd8:	eb 52                	jmp    c0028c2c <rehash+0x11a>

      old_bucket = &old_buckets[i];
      for (elem = list_begin (old_bucket);
           elem != list_end (old_bucket); elem = next) 
        {
          struct list *new_bucket
c0028bda:	89 da                	mov    %ebx,%edx
c0028bdc:	8b 44 24 0c          	mov    0xc(%esp),%eax
c0028be0:	e8 a0 fe ff ff       	call   c0028a85 <find_bucket>
c0028be5:	89 c7                	mov    %eax,%edi
            = find_bucket (h, list_elem_to_hash_elem (elem));
          next = list_next (elem);
c0028be7:	83 ec 0c             	sub    $0xc,%esp
c0028bea:	53                   	push   %ebx
c0028beb:	e8 39 ed ff ff       	call   c0027929 <list_next>
c0028bf0:	89 c6                	mov    %eax,%esi
          list_remove (elem);
c0028bf2:	89 1c 24             	mov    %ebx,(%esp)
c0028bf5:	e8 76 f1 ff ff       	call   c0027d70 <list_remove>
          list_push_front (new_bucket, elem);
c0028bfa:	83 c4 08             	add    $0x8,%esp
c0028bfd:	53                   	push   %ebx
c0028bfe:	57                   	push   %edi
c0028bff:	e8 32 f1 ff ff       	call   c0027d36 <list_push_front>
           elem != list_end (old_bucket); elem = next) 
c0028c04:	83 c4 10             	add    $0x10,%esp
c0028c07:	89 f3                	mov    %esi,%ebx
c0028c09:	83 ec 0c             	sub    $0xc,%esp
c0028c0c:	55                   	push   %ebp
c0028c0d:	e8 5f ed ff ff       	call   c0027971 <list_end>
      for (elem = list_begin (old_bucket);
c0028c12:	83 c4 10             	add    $0x10,%esp
c0028c15:	39 c3                	cmp    %eax,%ebx
c0028c17:	75 c1                	jne    c0028bda <rehash+0xc8>
  for (i = 0; i < old_bucket_cnt; i++) 
c0028c19:	ff 44 24 10          	incl   0x10(%esp)
c0028c1d:	8b 44 24 10          	mov    0x10(%esp),%eax
c0028c21:	83 44 24 14 10       	addl   $0x10,0x14(%esp)
c0028c26:	39 44 24 18          	cmp    %eax,0x18(%esp)
c0028c2a:	74 16                	je     c0028c42 <rehash+0x130>
      old_bucket = &old_buckets[i];
c0028c2c:	8b 44 24 14          	mov    0x14(%esp),%eax
c0028c30:	89 c5                	mov    %eax,%ebp
      for (elem = list_begin (old_bucket);
c0028c32:	83 ec 0c             	sub    $0xc,%esp
c0028c35:	50                   	push   %eax
c0028c36:	e8 be ec ff ff       	call   c00278f9 <list_begin>
c0028c3b:	89 c3                	mov    %eax,%ebx
c0028c3d:	83 c4 10             	add    $0x10,%esp
c0028c40:	eb c7                	jmp    c0028c09 <rehash+0xf7>
        }
    }

  free (old_buckets);
c0028c42:	83 ec 0c             	sub    $0xc,%esp
c0028c45:	ff 74 24 28          	pushl  0x28(%esp)
c0028c49:	e8 d5 a3 ff ff       	call   c0023023 <free>
c0028c4e:	83 c4 10             	add    $0x10,%esp
}
c0028c51:	83 c4 2c             	add    $0x2c,%esp
c0028c54:	5b                   	pop    %ebx
c0028c55:	5e                   	pop    %esi
c0028c56:	5f                   	pop    %edi
c0028c57:	5d                   	pop    %ebp
c0028c58:	c3                   	ret    

c0028c59 <hash_clear>:
{
c0028c59:	55                   	push   %ebp
c0028c5a:	57                   	push   %edi
c0028c5b:	56                   	push   %esi
c0028c5c:	53                   	push   %ebx
c0028c5d:	83 ec 0c             	sub    $0xc,%esp
c0028c60:	8b 74 24 20          	mov    0x20(%esp),%esi
c0028c64:	8b 7c 24 24          	mov    0x24(%esp),%edi
  for (i = 0; i < h->bucket_cnt; i++) 
c0028c68:	83 7e 04 00          	cmpl   $0x0,0x4(%esi)
c0028c6c:	74 4c                	je     c0028cba <hash_clear+0x61>
c0028c6e:	bd 00 00 00 00       	mov    $0x0,%ebp
c0028c73:	eb 37                	jmp    c0028cac <hash_clear+0x53>
            struct list_elem *list_elem = list_pop_front (bucket);
c0028c75:	83 ec 0c             	sub    $0xc,%esp
c0028c78:	53                   	push   %ebx
c0028c79:	e8 df f1 ff ff       	call   c0027e5d <list_pop_front>
            destructor (hash_elem, h->aux);
c0028c7e:	83 c4 08             	add    $0x8,%esp
c0028c81:	ff 76 14             	pushl  0x14(%esi)
c0028c84:	50                   	push   %eax
c0028c85:	ff d7                	call   *%edi
c0028c87:	83 c4 10             	add    $0x10,%esp
        while (!list_empty (bucket)) 
c0028c8a:	83 ec 0c             	sub    $0xc,%esp
c0028c8d:	53                   	push   %ebx
c0028c8e:	e8 68 f1 ff ff       	call   c0027dfb <list_empty>
c0028c93:	83 c4 10             	add    $0x10,%esp
c0028c96:	84 c0                	test   %al,%al
c0028c98:	74 db                	je     c0028c75 <hash_clear+0x1c>
      list_init (bucket); 
c0028c9a:	83 ec 0c             	sub    $0xc,%esp
c0028c9d:	53                   	push   %ebx
c0028c9e:	e8 13 ec ff ff       	call   c00278b6 <list_init>
  for (i = 0; i < h->bucket_cnt; i++) 
c0028ca3:	45                   	inc    %ebp
c0028ca4:	83 c4 10             	add    $0x10,%esp
c0028ca7:	39 6e 04             	cmp    %ebp,0x4(%esi)
c0028caa:	76 0e                	jbe    c0028cba <hash_clear+0x61>
      struct list *bucket = &h->buckets[i];
c0028cac:	89 eb                	mov    %ebp,%ebx
c0028cae:	c1 e3 04             	shl    $0x4,%ebx
c0028cb1:	03 5e 08             	add    0x8(%esi),%ebx
      if (destructor != NULL) 
c0028cb4:	85 ff                	test   %edi,%edi
c0028cb6:	75 d2                	jne    c0028c8a <hash_clear+0x31>
c0028cb8:	eb e0                	jmp    c0028c9a <hash_clear+0x41>
  h->elem_cnt = 0;
c0028cba:	c7 06 00 00 00 00    	movl   $0x0,(%esi)
}
c0028cc0:	83 c4 0c             	add    $0xc,%esp
c0028cc3:	5b                   	pop    %ebx
c0028cc4:	5e                   	pop    %esi
c0028cc5:	5f                   	pop    %edi
c0028cc6:	5d                   	pop    %ebp
c0028cc7:	c3                   	ret    

c0028cc8 <hash_init>:
{
c0028cc8:	53                   	push   %ebx
c0028cc9:	83 ec 14             	sub    $0x14,%esp
c0028ccc:	8b 5c 24 1c          	mov    0x1c(%esp),%ebx
  h->elem_cnt = 0;
c0028cd0:	c7 03 00 00 00 00    	movl   $0x0,(%ebx)
  h->bucket_cnt = 4;
c0028cd6:	c7 43 04 04 00 00 00 	movl   $0x4,0x4(%ebx)
  h->buckets = malloc (sizeof *h->buckets * h->bucket_cnt);
c0028cdd:	6a 40                	push   $0x40
c0028cdf:	e8 9e a1 ff ff       	call   c0022e82 <malloc>
c0028ce4:	89 43 08             	mov    %eax,0x8(%ebx)
  h->hash = hash;
c0028ce7:	8b 54 24 24          	mov    0x24(%esp),%edx
c0028ceb:	89 53 0c             	mov    %edx,0xc(%ebx)
  h->less = less;
c0028cee:	8b 54 24 28          	mov    0x28(%esp),%edx
c0028cf2:	89 53 10             	mov    %edx,0x10(%ebx)
  h->aux = aux;
c0028cf5:	8b 54 24 2c          	mov    0x2c(%esp),%edx
c0028cf9:	89 53 14             	mov    %edx,0x14(%ebx)
  if (h->buckets != NULL) 
c0028cfc:	83 c4 10             	add    $0x10,%esp
c0028cff:	85 c0                	test   %eax,%eax
c0028d01:	74 15                	je     c0028d18 <hash_init+0x50>
      hash_clear (h, NULL);
c0028d03:	83 ec 08             	sub    $0x8,%esp
c0028d06:	6a 00                	push   $0x0
c0028d08:	53                   	push   %ebx
c0028d09:	e8 4b ff ff ff       	call   c0028c59 <hash_clear>
      return true;
c0028d0e:	83 c4 10             	add    $0x10,%esp
c0028d11:	b0 01                	mov    $0x1,%al
}
c0028d13:	83 c4 08             	add    $0x8,%esp
c0028d16:	5b                   	pop    %ebx
c0028d17:	c3                   	ret    
    return false;
c0028d18:	b0 00                	mov    $0x0,%al
c0028d1a:	eb f7                	jmp    c0028d13 <hash_init+0x4b>

c0028d1c <hash_destroy>:
{
c0028d1c:	53                   	push   %ebx
c0028d1d:	83 ec 08             	sub    $0x8,%esp
c0028d20:	8b 5c 24 10          	mov    0x10(%esp),%ebx
c0028d24:	8b 44 24 14          	mov    0x14(%esp),%eax
  if (destructor != NULL)
c0028d28:	85 c0                	test   %eax,%eax
c0028d2a:	74 0d                	je     c0028d39 <hash_destroy+0x1d>
    hash_clear (h, destructor);
c0028d2c:	83 ec 08             	sub    $0x8,%esp
c0028d2f:	50                   	push   %eax
c0028d30:	53                   	push   %ebx
c0028d31:	e8 23 ff ff ff       	call   c0028c59 <hash_clear>
c0028d36:	83 c4 10             	add    $0x10,%esp
  free (h->buckets);
c0028d39:	83 ec 0c             	sub    $0xc,%esp
c0028d3c:	ff 73 08             	pushl  0x8(%ebx)
c0028d3f:	e8 df a2 ff ff       	call   c0023023 <free>
}
c0028d44:	83 c4 18             	add    $0x18,%esp
c0028d47:	5b                   	pop    %ebx
c0028d48:	c3                   	ret    

c0028d49 <hash_insert>:
{
c0028d49:	55                   	push   %ebp
c0028d4a:	57                   	push   %edi
c0028d4b:	56                   	push   %esi
c0028d4c:	53                   	push   %ebx
c0028d4d:	83 ec 0c             	sub    $0xc,%esp
c0028d50:	8b 5c 24 20          	mov    0x20(%esp),%ebx
c0028d54:	8b 74 24 24          	mov    0x24(%esp),%esi
  struct list *bucket = find_bucket (h, new);
c0028d58:	89 f2                	mov    %esi,%edx
c0028d5a:	89 d8                	mov    %ebx,%eax
c0028d5c:	e8 24 fd ff ff       	call   c0028a85 <find_bucket>
c0028d61:	89 c5                	mov    %eax,%ebp
  struct hash_elem *old = find_elem (h, bucket, new);
c0028d63:	89 f1                	mov    %esi,%ecx
c0028d65:	89 c2                	mov    %eax,%edx
c0028d67:	89 d8                	mov    %ebx,%eax
c0028d69:	e8 37 fd ff ff       	call   c0028aa5 <find_elem>
c0028d6e:	89 c7                	mov    %eax,%edi
  if (old == NULL) 
c0028d70:	85 c0                	test   %eax,%eax
c0028d72:	74 11                	je     c0028d85 <hash_insert+0x3c>
  rehash (h);
c0028d74:	89 d8                	mov    %ebx,%eax
c0028d76:	e8 97 fd ff ff       	call   c0028b12 <rehash>
}
c0028d7b:	89 f8                	mov    %edi,%eax
c0028d7d:	83 c4 0c             	add    $0xc,%esp
c0028d80:	5b                   	pop    %ebx
c0028d81:	5e                   	pop    %esi
c0028d82:	5f                   	pop    %edi
c0028d83:	5d                   	pop    %ebp
c0028d84:	c3                   	ret    

/* Inserts E into BUCKET (in hash table H). */
static void
insert_elem (struct hash *h, struct list *bucket, struct hash_elem *e) 
{
  h->elem_cnt++;
c0028d85:	ff 03                	incl   (%ebx)
  list_push_front (bucket, &e->list_elem);
c0028d87:	83 ec 08             	sub    $0x8,%esp
c0028d8a:	56                   	push   %esi
c0028d8b:	55                   	push   %ebp
c0028d8c:	e8 a5 ef ff ff       	call   c0027d36 <list_push_front>
c0028d91:	83 c4 10             	add    $0x10,%esp
c0028d94:	eb de                	jmp    c0028d74 <hash_insert+0x2b>

c0028d96 <hash_replace>:
{
c0028d96:	55                   	push   %ebp
c0028d97:	57                   	push   %edi
c0028d98:	56                   	push   %esi
c0028d99:	53                   	push   %ebx
c0028d9a:	83 ec 0c             	sub    $0xc,%esp
c0028d9d:	8b 5c 24 20          	mov    0x20(%esp),%ebx
c0028da1:	8b 74 24 24          	mov    0x24(%esp),%esi
  struct list *bucket = find_bucket (h, new);
c0028da5:	89 f2                	mov    %esi,%edx
c0028da7:	89 d8                	mov    %ebx,%eax
c0028da9:	e8 d7 fc ff ff       	call   c0028a85 <find_bucket>
c0028dae:	89 c5                	mov    %eax,%ebp
  struct hash_elem *old = find_elem (h, bucket, new);
c0028db0:	89 f1                	mov    %esi,%ecx
c0028db2:	89 c2                	mov    %eax,%edx
c0028db4:	89 d8                	mov    %ebx,%eax
c0028db6:	e8 ea fc ff ff       	call   c0028aa5 <find_elem>
c0028dbb:	89 c7                	mov    %eax,%edi
  if (old != NULL)
c0028dbd:	85 c0                	test   %eax,%eax
c0028dbf:	74 0e                	je     c0028dcf <hash_replace+0x39>

/* Removes E from hash table H. */
static void
remove_elem (struct hash *h, struct hash_elem *e) 
{
  h->elem_cnt--;
c0028dc1:	ff 0b                	decl   (%ebx)
  list_remove (&e->list_elem);
c0028dc3:	83 ec 0c             	sub    $0xc,%esp
c0028dc6:	50                   	push   %eax
c0028dc7:	e8 a4 ef ff ff       	call   c0027d70 <list_remove>
c0028dcc:	83 c4 10             	add    $0x10,%esp
  h->elem_cnt++;
c0028dcf:	ff 03                	incl   (%ebx)
  list_push_front (bucket, &e->list_elem);
c0028dd1:	83 ec 08             	sub    $0x8,%esp
c0028dd4:	56                   	push   %esi
c0028dd5:	55                   	push   %ebp
c0028dd6:	e8 5b ef ff ff       	call   c0027d36 <list_push_front>
  rehash (h);
c0028ddb:	89 d8                	mov    %ebx,%eax
c0028ddd:	e8 30 fd ff ff       	call   c0028b12 <rehash>
}
c0028de2:	89 f8                	mov    %edi,%eax
c0028de4:	83 c4 1c             	add    $0x1c,%esp
c0028de7:	5b                   	pop    %ebx
c0028de8:	5e                   	pop    %esi
c0028de9:	5f                   	pop    %edi
c0028dea:	5d                   	pop    %ebp
c0028deb:	c3                   	ret    

c0028dec <hash_find>:
{
c0028dec:	83 ec 0c             	sub    $0xc,%esp
  return find_elem (h, find_bucket (h, e), e);
c0028def:	8b 54 24 14          	mov    0x14(%esp),%edx
c0028df3:	8b 44 24 10          	mov    0x10(%esp),%eax
c0028df7:	e8 89 fc ff ff       	call   c0028a85 <find_bucket>
c0028dfc:	8b 4c 24 14          	mov    0x14(%esp),%ecx
c0028e00:	89 c2                	mov    %eax,%edx
c0028e02:	8b 44 24 10          	mov    0x10(%esp),%eax
c0028e06:	e8 9a fc ff ff       	call   c0028aa5 <find_elem>
}
c0028e0b:	83 c4 0c             	add    $0xc,%esp
c0028e0e:	c3                   	ret    

c0028e0f <hash_delete>:
{
c0028e0f:	56                   	push   %esi
c0028e10:	53                   	push   %ebx
c0028e11:	83 ec 04             	sub    $0x4,%esp
c0028e14:	8b 5c 24 10          	mov    0x10(%esp),%ebx
c0028e18:	8b 74 24 14          	mov    0x14(%esp),%esi
  struct hash_elem *found = find_elem (h, find_bucket (h, e), e);
c0028e1c:	89 f2                	mov    %esi,%edx
c0028e1e:	89 d8                	mov    %ebx,%eax
c0028e20:	e8 60 fc ff ff       	call   c0028a85 <find_bucket>
c0028e25:	89 f1                	mov    %esi,%ecx
c0028e27:	89 c2                	mov    %eax,%edx
c0028e29:	89 d8                	mov    %ebx,%eax
c0028e2b:	e8 75 fc ff ff       	call   c0028aa5 <find_elem>
c0028e30:	89 c6                	mov    %eax,%esi
  if (found != NULL) 
c0028e32:	85 c0                	test   %eax,%eax
c0028e34:	74 15                	je     c0028e4b <hash_delete+0x3c>
  h->elem_cnt--;
c0028e36:	ff 0b                	decl   (%ebx)
  list_remove (&e->list_elem);
c0028e38:	83 ec 0c             	sub    $0xc,%esp
c0028e3b:	50                   	push   %eax
c0028e3c:	e8 2f ef ff ff       	call   c0027d70 <list_remove>
      rehash (h); 
c0028e41:	89 d8                	mov    %ebx,%eax
c0028e43:	e8 ca fc ff ff       	call   c0028b12 <rehash>
c0028e48:	83 c4 10             	add    $0x10,%esp
}
c0028e4b:	89 f0                	mov    %esi,%eax
c0028e4d:	83 c4 04             	add    $0x4,%esp
c0028e50:	5b                   	pop    %ebx
c0028e51:	5e                   	pop    %esi
c0028e52:	c3                   	ret    

c0028e53 <hash_apply>:
{
c0028e53:	55                   	push   %ebp
c0028e54:	57                   	push   %edi
c0028e55:	56                   	push   %esi
c0028e56:	53                   	push   %ebx
c0028e57:	83 ec 1c             	sub    $0x1c,%esp
c0028e5a:	8b 6c 24 30          	mov    0x30(%esp),%ebp
  ASSERT (action != NULL);
c0028e5e:	83 7c 24 34 00       	cmpl   $0x0,0x34(%esp)
c0028e63:	74 16                	je     c0028e7b <hash_apply+0x28>
  for (i = 0; i < h->bucket_cnt; i++) 
c0028e65:	c7 44 24 0c 00 00 00 	movl   $0x0,0xc(%esp)
c0028e6c:	00 
c0028e6d:	83 7d 04 00          	cmpl   $0x0,0x4(%ebp)
c0028e71:	75 61                	jne    c0028ed4 <hash_apply+0x81>
}
c0028e73:	83 c4 1c             	add    $0x1c,%esp
c0028e76:	5b                   	pop    %ebx
c0028e77:	5e                   	pop    %esi
c0028e78:	5f                   	pop    %edi
c0028e79:	5d                   	pop    %ebp
c0028e7a:	c3                   	ret    
  ASSERT (action != NULL);
c0028e7b:	83 ec 0c             	sub    $0xc,%esp
c0028e7e:	68 f2 e9 02 c0       	push   $0xc002e9f2
c0028e83:	68 9f cd 02 c0       	push   $0xc002cd9f
c0028e88:	68 34 ca 02 c0       	push   $0xc002ca34
c0028e8d:	68 a7 00 00 00       	push   $0xa7
c0028e92:	68 da e9 02 c0       	push   $0xc002e9da
c0028e97:	e8 73 e9 ff ff       	call   c002780f <debug_panic>
          next = list_next (elem);
c0028e9c:	83 ec 0c             	sub    $0xc,%esp
c0028e9f:	53                   	push   %ebx
c0028ea0:	e8 84 ea ff ff       	call   c0027929 <list_next>
c0028ea5:	89 c6                	mov    %eax,%esi
          action (list_elem_to_hash_elem (elem), h->aux);
c0028ea7:	83 c4 08             	add    $0x8,%esp
c0028eaa:	ff 75 14             	pushl  0x14(%ebp)
c0028ead:	53                   	push   %ebx
c0028eae:	ff 54 24 44          	call   *0x44(%esp)
      for (elem = list_begin (bucket); elem != list_end (bucket); elem = next) 
c0028eb2:	83 c4 10             	add    $0x10,%esp
c0028eb5:	89 f3                	mov    %esi,%ebx
c0028eb7:	83 ec 0c             	sub    $0xc,%esp
c0028eba:	57                   	push   %edi
c0028ebb:	e8 b1 ea ff ff       	call   c0027971 <list_end>
c0028ec0:	83 c4 10             	add    $0x10,%esp
c0028ec3:	39 c3                	cmp    %eax,%ebx
c0028ec5:	75 d5                	jne    c0028e9c <hash_apply+0x49>
  for (i = 0; i < h->bucket_cnt; i++) 
c0028ec7:	ff 44 24 0c          	incl   0xc(%esp)
c0028ecb:	8b 44 24 0c          	mov    0xc(%esp),%eax
c0028ecf:	39 45 04             	cmp    %eax,0x4(%ebp)
c0028ed2:	76 9f                	jbe    c0028e73 <hash_apply+0x20>
      struct list *bucket = &h->buckets[i];
c0028ed4:	8b 7c 24 0c          	mov    0xc(%esp),%edi
c0028ed8:	c1 e7 04             	shl    $0x4,%edi
c0028edb:	03 7d 08             	add    0x8(%ebp),%edi
      for (elem = list_begin (bucket); elem != list_end (bucket); elem = next) 
c0028ede:	83 ec 0c             	sub    $0xc,%esp
c0028ee1:	57                   	push   %edi
c0028ee2:	e8 12 ea ff ff       	call   c00278f9 <list_begin>
c0028ee7:	89 c3                	mov    %eax,%ebx
c0028ee9:	83 c4 10             	add    $0x10,%esp
c0028eec:	eb c9                	jmp    c0028eb7 <hash_apply+0x64>

c0028eee <hash_first>:
{
c0028eee:	53                   	push   %ebx
c0028eef:	83 ec 08             	sub    $0x8,%esp
c0028ef2:	8b 5c 24 10          	mov    0x10(%esp),%ebx
c0028ef6:	8b 44 24 14          	mov    0x14(%esp),%eax
  ASSERT (i != NULL);
c0028efa:	85 db                	test   %ebx,%ebx
c0028efc:	74 1d                	je     c0028f1b <hash_first+0x2d>
  ASSERT (h != NULL);
c0028efe:	85 c0                	test   %eax,%eax
c0028f00:	74 3a                	je     c0028f3c <hash_first+0x4e>
  i->hash = h;
c0028f02:	89 03                	mov    %eax,(%ebx)
  i->bucket = i->hash->buckets;
c0028f04:	8b 40 08             	mov    0x8(%eax),%eax
c0028f07:	89 43 04             	mov    %eax,0x4(%ebx)
  i->elem = list_elem_to_hash_elem (list_head (i->bucket));
c0028f0a:	83 ec 0c             	sub    $0xc,%esp
c0028f0d:	50                   	push   %eax
c0028f0e:	e8 67 ec ff ff       	call   c0027b7a <list_head>
c0028f13:	89 43 08             	mov    %eax,0x8(%ebx)
}
c0028f16:	83 c4 18             	add    $0x18,%esp
c0028f19:	5b                   	pop    %ebx
c0028f1a:	c3                   	ret    
  ASSERT (i != NULL);
c0028f1b:	83 ec 0c             	sub    $0xc,%esp
c0028f1e:	68 01 ea 02 c0       	push   $0xc002ea01
c0028f23:	68 9f cd 02 c0       	push   $0xc002cd9f
c0028f28:	68 28 ca 02 c0       	push   $0xc002ca28
c0028f2d:	68 ca 00 00 00       	push   $0xca
c0028f32:	68 da e9 02 c0       	push   $0xc002e9da
c0028f37:	e8 d3 e8 ff ff       	call   c002780f <debug_panic>
  ASSERT (h != NULL);
c0028f3c:	83 ec 0c             	sub    $0xc,%esp
c0028f3f:	68 d0 e9 02 c0       	push   $0xc002e9d0
c0028f44:	68 9f cd 02 c0       	push   $0xc002cd9f
c0028f49:	68 28 ca 02 c0       	push   $0xc002ca28
c0028f4e:	68 cb 00 00 00       	push   $0xcb
c0028f53:	68 da e9 02 c0       	push   $0xc002e9da
c0028f58:	e8 b2 e8 ff ff       	call   c002780f <debug_panic>

c0028f5d <hash_next>:
{
c0028f5d:	56                   	push   %esi
c0028f5e:	53                   	push   %ebx
c0028f5f:	83 ec 04             	sub    $0x4,%esp
c0028f62:	8b 5c 24 10          	mov    0x10(%esp),%ebx
  ASSERT (i != NULL);
c0028f66:	85 db                	test   %ebx,%ebx
c0028f68:	74 4f                	je     c0028fb9 <hash_next+0x5c>
  i->elem = list_elem_to_hash_elem (list_next (&i->elem->list_elem));
c0028f6a:	83 ec 0c             	sub    $0xc,%esp
c0028f6d:	ff 73 08             	pushl  0x8(%ebx)
c0028f70:	e8 b4 e9 ff ff       	call   c0027929 <list_next>
c0028f75:	89 43 08             	mov    %eax,0x8(%ebx)
  while (i->elem == list_elem_to_hash_elem (list_end (i->bucket)))
c0028f78:	83 c4 10             	add    $0x10,%esp
c0028f7b:	8b 73 08             	mov    0x8(%ebx),%esi
c0028f7e:	83 ec 0c             	sub    $0xc,%esp
c0028f81:	ff 73 04             	pushl  0x4(%ebx)
c0028f84:	e8 e8 e9 ff ff       	call   c0027971 <list_end>
c0028f89:	83 c4 10             	add    $0x10,%esp
c0028f8c:	39 c6                	cmp    %eax,%esi
c0028f8e:	75 51                	jne    c0028fe1 <hash_next+0x84>
      if (++i->bucket >= i->hash->buckets + i->hash->bucket_cnt)
c0028f90:	8b 43 04             	mov    0x4(%ebx),%eax
c0028f93:	8d 50 10             	lea    0x10(%eax),%edx
c0028f96:	89 53 04             	mov    %edx,0x4(%ebx)
c0028f99:	8b 0b                	mov    (%ebx),%ecx
c0028f9b:	8b 41 04             	mov    0x4(%ecx),%eax
c0028f9e:	c1 e0 04             	shl    $0x4,%eax
c0028fa1:	03 41 08             	add    0x8(%ecx),%eax
c0028fa4:	39 c2                	cmp    %eax,%edx
c0028fa6:	73 32                	jae    c0028fda <hash_next+0x7d>
      i->elem = list_elem_to_hash_elem (list_begin (i->bucket));
c0028fa8:	83 ec 0c             	sub    $0xc,%esp
c0028fab:	52                   	push   %edx
c0028fac:	e8 48 e9 ff ff       	call   c00278f9 <list_begin>
c0028fb1:	89 43 08             	mov    %eax,0x8(%ebx)
c0028fb4:	83 c4 10             	add    $0x10,%esp
c0028fb7:	eb c2                	jmp    c0028f7b <hash_next+0x1e>
  ASSERT (i != NULL);
c0028fb9:	83 ec 0c             	sub    $0xc,%esp
c0028fbc:	68 01 ea 02 c0       	push   $0xc002ea01
c0028fc1:	68 9f cd 02 c0       	push   $0xc002cd9f
c0028fc6:	68 1c ca 02 c0       	push   $0xc002ca1c
c0028fcb:	68 dd 00 00 00       	push   $0xdd
c0028fd0:	68 da e9 02 c0       	push   $0xc002e9da
c0028fd5:	e8 35 e8 ff ff       	call   c002780f <debug_panic>
          i->elem = NULL;
c0028fda:	c7 43 08 00 00 00 00 	movl   $0x0,0x8(%ebx)
  return i->elem;
c0028fe1:	8b 43 08             	mov    0x8(%ebx),%eax
}
c0028fe4:	83 c4 04             	add    $0x4,%esp
c0028fe7:	5b                   	pop    %ebx
c0028fe8:	5e                   	pop    %esi
c0028fe9:	c3                   	ret    

c0028fea <hash_cur>:
  return i->elem;
c0028fea:	8b 44 24 04          	mov    0x4(%esp),%eax
c0028fee:	8b 40 08             	mov    0x8(%eax),%eax
}
c0028ff1:	c3                   	ret    

c0028ff2 <hash_size>:
  return h->elem_cnt;
c0028ff2:	8b 44 24 04          	mov    0x4(%esp),%eax
c0028ff6:	8b 00                	mov    (%eax),%eax
}
c0028ff8:	c3                   	ret    

c0028ff9 <hash_empty>:
  return h->elem_cnt == 0;
c0028ff9:	8b 44 24 04          	mov    0x4(%esp),%eax
c0028ffd:	83 38 00             	cmpl   $0x0,(%eax)
c0029000:	0f 94 c0             	sete   %al
}
c0029003:	c3                   	ret    

c0029004 <hash_bytes>:
{
c0029004:	53                   	push   %ebx
c0029005:	83 ec 08             	sub    $0x8,%esp
c0029008:	8b 4c 24 10          	mov    0x10(%esp),%ecx
c002900c:	8b 5c 24 14          	mov    0x14(%esp),%ebx
  ASSERT (buf != NULL);
c0029010:	85 c9                	test   %ecx,%ecx
c0029012:	74 35                	je     c0029049 <hash_bytes+0x45>
  while (size-- > 0)
c0029014:	b8 c5 9d 1c 81       	mov    $0x811c9dc5,%eax
c0029019:	85 db                	test   %ebx,%ebx
c002901b:	74 27                	je     c0029044 <hash_bytes+0x40>
c002901d:	01 cb                	add    %ecx,%ebx
c002901f:	b8 c5 9d 1c 81       	mov    $0x811c9dc5,%eax
    hash = (hash * FNV_32_PRIME) ^ *buf++;
c0029024:	89 c2                	mov    %eax,%edx
c0029026:	c1 e2 10             	shl    $0x10,%edx
c0029029:	01 c2                	add    %eax,%edx
c002902b:	01 d2                	add    %edx,%edx
c002902d:	01 c2                	add    %eax,%edx
c002902f:	8d 14 d0             	lea    (%eax,%edx,8),%edx
c0029032:	8d 14 d0             	lea    (%eax,%edx,8),%edx
c0029035:	01 d2                	add    %edx,%edx
c0029037:	01 d0                	add    %edx,%eax
c0029039:	41                   	inc    %ecx
c002903a:	0f b6 51 ff          	movzbl -0x1(%ecx),%edx
c002903e:	31 d0                	xor    %edx,%eax
  while (size-- > 0)
c0029040:	39 d9                	cmp    %ebx,%ecx
c0029042:	75 e0                	jne    c0029024 <hash_bytes+0x20>
} 
c0029044:	83 c4 08             	add    $0x8,%esp
c0029047:	5b                   	pop    %ebx
c0029048:	c3                   	ret    
  ASSERT (buf != NULL);
c0029049:	83 ec 0c             	sub    $0xc,%esp
c002904c:	68 0b ea 02 c0       	push   $0xc002ea0b
c0029051:	68 9f cd 02 c0       	push   $0xc002cd9f
c0029056:	68 10 ca 02 c0       	push   $0xc002ca10
c002905b:	68 10 01 00 00       	push   $0x110
c0029060:	68 da e9 02 c0       	push   $0xc002e9da
c0029065:	e8 a5 e7 ff ff       	call   c002780f <debug_panic>

c002906a <hash_string>:
{
c002906a:	53                   	push   %ebx
c002906b:	83 ec 08             	sub    $0x8,%esp
c002906e:	8b 5c 24 10          	mov    0x10(%esp),%ebx
  ASSERT (s != NULL);
c0029072:	85 db                	test   %ebx,%ebx
c0029074:	74 36                	je     c00290ac <hash_string+0x42>
  while (*s != '\0')
c0029076:	8a 0b                	mov    (%ebx),%cl
c0029078:	b8 c5 9d 1c 81       	mov    $0x811c9dc5,%eax
c002907d:	84 c9                	test   %cl,%cl
c002907f:	74 26                	je     c00290a7 <hash_string+0x3d>
c0029081:	b8 c5 9d 1c 81       	mov    $0x811c9dc5,%eax
    hash = (hash * FNV_32_PRIME) ^ *s++;
c0029086:	89 c2                	mov    %eax,%edx
c0029088:	c1 e2 10             	shl    $0x10,%edx
c002908b:	01 c2                	add    %eax,%edx
c002908d:	01 d2                	add    %edx,%edx
c002908f:	01 c2                	add    %eax,%edx
c0029091:	8d 14 d0             	lea    (%eax,%edx,8),%edx
c0029094:	8d 14 d0             	lea    (%eax,%edx,8),%edx
c0029097:	01 d2                	add    %edx,%edx
c0029099:	01 d0                	add    %edx,%eax
c002909b:	43                   	inc    %ebx
c002909c:	0f b6 c9             	movzbl %cl,%ecx
c002909f:	31 c8                	xor    %ecx,%eax
  while (*s != '\0')
c00290a1:	8a 0b                	mov    (%ebx),%cl
c00290a3:	84 c9                	test   %cl,%cl
c00290a5:	75 df                	jne    c0029086 <hash_string+0x1c>
}
c00290a7:	83 c4 08             	add    $0x8,%esp
c00290aa:	5b                   	pop    %ebx
c00290ab:	c3                   	ret    
  ASSERT (s != NULL);
c00290ac:	83 ec 0c             	sub    $0xc,%esp
c00290af:	68 97 e5 02 c0       	push   $0xc002e597
c00290b4:	68 9f cd 02 c0       	push   $0xc002cd9f
c00290b9:	68 04 ca 02 c0       	push   $0xc002ca04
c00290be:	68 20 01 00 00       	push   $0x120
c00290c3:	68 da e9 02 c0       	push   $0xc002e9da
c00290c8:	e8 42 e7 ff ff       	call   c002780f <debug_panic>

c00290cd <hash_int>:
{
c00290cd:	83 ec 14             	sub    $0x14,%esp
  return hash_bytes (&i, sizeof i);
c00290d0:	6a 04                	push   $0x4
c00290d2:	8d 44 24 1c          	lea    0x1c(%esp),%eax
c00290d6:	50                   	push   %eax
c00290d7:	e8 28 ff ff ff       	call   c0029004 <hash_bytes>
}
c00290dc:	83 c4 1c             	add    $0x1c,%esp
c00290df:	c3                   	ret    

c00290e0 <putchar_have_lock>:
/* Writes C to the vga display and serial port.
   The caller has already acquired the console lock if
   appropriate. */
static void
putchar_have_lock (uint8_t c) 
{
c00290e0:	53                   	push   %ebx
c00290e1:	83 ec 08             	sub    $0x8,%esp
c00290e4:	89 c3                	mov    %eax,%ebx
  return (intr_context ()
c00290e6:	e8 8a 83 ff ff       	call   c0021475 <intr_context>
          || lock_held_by_current_thread (&console_lock));
c00290eb:	84 c0                	test   %al,%al
c00290ed:	75 09                	jne    c00290f8 <putchar_have_lock+0x18>
          || !use_console_lock
c00290ef:	80 3d 54 84 03 c0 00 	cmpb   $0x0,0xc0038454
c00290f6:	75 27                	jne    c002911f <putchar_have_lock+0x3f>
  ASSERT (console_locked_by_current_thread ());
  write_cnt++;
c00290f8:	83 05 48 84 03 c0 01 	addl   $0x1,0xc0038448
c00290ff:	83 15 4c 84 03 c0 00 	adcl   $0x0,0xc003844c
  serial_putc (c);
c0029106:	0f b6 db             	movzbl %bl,%ebx
c0029109:	83 ec 0c             	sub    $0xc,%esp
c002910c:	53                   	push   %ebx
c002910d:	e8 77 ab ff ff       	call   c0023c89 <serial_putc>
  vga_putc (c);
c0029112:	89 1c 24             	mov    %ebx,(%esp)
c0029115:	e8 c1 a7 ff ff       	call   c00238db <vga_putc>
}
c002911a:	83 c4 18             	add    $0x18,%esp
c002911d:	5b                   	pop    %ebx
c002911e:	c3                   	ret    
          || lock_held_by_current_thread (&console_lock));
c002911f:	83 ec 0c             	sub    $0xc,%esp
c0029122:	68 58 84 03 c0       	push   $0xc0038458
c0029127:	e8 cd 93 ff ff       	call   c00224f9 <lock_held_by_current_thread>
  ASSERT (console_locked_by_current_thread ());
c002912c:	83 c4 10             	add    $0x10,%esp
c002912f:	84 c0                	test   %al,%al
c0029131:	75 c5                	jne    c00290f8 <putchar_have_lock+0x18>
c0029133:	83 ec 0c             	sub    $0xc,%esp
c0029136:	68 18 ea 02 c0       	push   $0xc002ea18
c002913b:	68 9f cd 02 c0       	push   $0xc002cd9f
c0029140:	68 48 ca 02 c0       	push   $0xc002ca48
c0029145:	68 bb 00 00 00       	push   $0xbb
c002914a:	68 5d ea 02 c0       	push   $0xc002ea5d
c002914f:	e8 bb e6 ff ff       	call   c002780f <debug_panic>

c0029154 <vprintf_helper>:
{
c0029154:	83 ec 0c             	sub    $0xc,%esp
c0029157:	8b 44 24 14          	mov    0x14(%esp),%eax
  (*char_cnt)++;
c002915b:	ff 00                	incl   (%eax)
  putchar_have_lock (c);
c002915d:	0f b6 44 24 10       	movzbl 0x10(%esp),%eax
c0029162:	e8 79 ff ff ff       	call   c00290e0 <putchar_have_lock>
}
c0029167:	83 c4 0c             	add    $0xc,%esp
c002916a:	c3                   	ret    

c002916b <acquire_console>:
{
c002916b:	83 ec 0c             	sub    $0xc,%esp
  if (!intr_context () && use_console_lock) 
c002916e:	e8 02 83 ff ff       	call   c0021475 <intr_context>
c0029173:	84 c0                	test   %al,%al
c0029175:	75 09                	jne    c0029180 <acquire_console+0x15>
c0029177:	80 3d 54 84 03 c0 00 	cmpb   $0x0,0xc0038454
c002917e:	75 04                	jne    c0029184 <acquire_console+0x19>
}
c0029180:	83 c4 0c             	add    $0xc,%esp
c0029183:	c3                   	ret    
      if (lock_held_by_current_thread (&console_lock)) 
c0029184:	83 ec 0c             	sub    $0xc,%esp
c0029187:	68 58 84 03 c0       	push   $0xc0038458
c002918c:	e8 68 93 ff ff       	call   c00224f9 <lock_held_by_current_thread>
c0029191:	83 c4 10             	add    $0x10,%esp
c0029194:	84 c0                	test   %al,%al
c0029196:	74 08                	je     c00291a0 <acquire_console+0x35>
        console_lock_depth++; 
c0029198:	ff 05 50 84 03 c0    	incl   0xc0038450
c002919e:	eb e0                	jmp    c0029180 <acquire_console+0x15>
        lock_acquire (&console_lock); 
c00291a0:	83 ec 0c             	sub    $0xc,%esp
c00291a3:	68 58 84 03 c0       	push   $0xc0038458
c00291a8:	e8 8a 93 ff ff       	call   c0022537 <lock_acquire>
c00291ad:	83 c4 10             	add    $0x10,%esp
}
c00291b0:	eb ce                	jmp    c0029180 <acquire_console+0x15>

c00291b2 <release_console>:
{
c00291b2:	83 ec 0c             	sub    $0xc,%esp
  if (!intr_context () && use_console_lock) 
c00291b5:	e8 bb 82 ff ff       	call   c0021475 <intr_context>
c00291ba:	84 c0                	test   %al,%al
c00291bc:	75 18                	jne    c00291d6 <release_console+0x24>
c00291be:	80 3d 54 84 03 c0 00 	cmpb   $0x0,0xc0038454
c00291c5:	74 0f                	je     c00291d6 <release_console+0x24>
      if (console_lock_depth > 0)
c00291c7:	a1 50 84 03 c0       	mov    0xc0038450,%eax
c00291cc:	85 c0                	test   %eax,%eax
c00291ce:	7e 0a                	jle    c00291da <release_console+0x28>
        console_lock_depth--;
c00291d0:	48                   	dec    %eax
c00291d1:	a3 50 84 03 c0       	mov    %eax,0xc0038450
}
c00291d6:	83 c4 0c             	add    $0xc,%esp
c00291d9:	c3                   	ret    
        lock_release (&console_lock); 
c00291da:	83 ec 0c             	sub    $0xc,%esp
c00291dd:	68 58 84 03 c0       	push   $0xc0038458
c00291e2:	e8 75 94 ff ff       	call   c002265c <lock_release>
c00291e7:	83 c4 10             	add    $0x10,%esp
}
c00291ea:	eb ea                	jmp    c00291d6 <release_console+0x24>

c00291ec <console_init>:
{
c00291ec:	83 ec 18             	sub    $0x18,%esp
  lock_init (&console_lock);
c00291ef:	68 58 84 03 c0       	push   $0xc0038458
c00291f4:	e8 bc 92 ff ff       	call   c00224b5 <lock_init>
  use_console_lock = true;
c00291f9:	c6 05 54 84 03 c0 01 	movb   $0x1,0xc0038454
}
c0029200:	83 c4 1c             	add    $0x1c,%esp
c0029203:	c3                   	ret    

c0029204 <console_panic>:
  use_console_lock = false;
c0029204:	c6 05 54 84 03 c0 00 	movb   $0x0,0xc0038454
c002920b:	c3                   	ret    

c002920c <console_print_stats>:
{
c002920c:	83 ec 10             	sub    $0x10,%esp
  printf ("Console: %lld characters output\n", write_cnt);
c002920f:	ff 35 4c 84 03 c0    	pushl  0xc003844c
c0029215:	ff 35 48 84 03 c0    	pushl  0xc0038448
c002921b:	68 3c ea 02 c0       	push   $0xc002ea3c
c0029220:	e8 3c cb ff ff       	call   c0025d61 <printf>
}
c0029225:	83 c4 1c             	add    $0x1c,%esp
c0029228:	c3                   	ret    

c0029229 <vprintf>:
{
c0029229:	83 ec 1c             	sub    $0x1c,%esp
  int char_cnt = 0;
c002922c:	c7 44 24 0c 00 00 00 	movl   $0x0,0xc(%esp)
c0029233:	00 
  acquire_console ();
c0029234:	e8 32 ff ff ff       	call   c002916b <acquire_console>
  __vprintf (format, args, vprintf_helper, &char_cnt);
c0029239:	8d 44 24 0c          	lea    0xc(%esp),%eax
c002923d:	50                   	push   %eax
c002923e:	68 54 91 02 c0       	push   $0xc0029154
c0029243:	ff 74 24 2c          	pushl  0x2c(%esp)
c0029247:	ff 74 24 2c          	pushl  0x2c(%esp)
c002924b:	e8 46 cb ff ff       	call   c0025d96 <__vprintf>
  release_console ();
c0029250:	e8 5d ff ff ff       	call   c00291b2 <release_console>
}
c0029255:	8b 44 24 1c          	mov    0x1c(%esp),%eax
c0029259:	83 c4 2c             	add    $0x2c,%esp
c002925c:	c3                   	ret    

c002925d <puts>:
{
c002925d:	53                   	push   %ebx
c002925e:	83 ec 08             	sub    $0x8,%esp
c0029261:	8b 5c 24 10          	mov    0x10(%esp),%ebx
  acquire_console ();
c0029265:	e8 01 ff ff ff       	call   c002916b <acquire_console>
  while (*s != '\0')
c002926a:	8a 03                	mov    (%ebx),%al
c002926c:	84 c0                	test   %al,%al
c002926e:	74 0f                	je     c002927f <puts+0x22>
    putchar_have_lock (*s++);
c0029270:	43                   	inc    %ebx
c0029271:	0f b6 c0             	movzbl %al,%eax
c0029274:	e8 67 fe ff ff       	call   c00290e0 <putchar_have_lock>
  while (*s != '\0')
c0029279:	8a 03                	mov    (%ebx),%al
c002927b:	84 c0                	test   %al,%al
c002927d:	75 f1                	jne    c0029270 <puts+0x13>
  putchar_have_lock ('\n');
c002927f:	b8 0a 00 00 00       	mov    $0xa,%eax
c0029284:	e8 57 fe ff ff       	call   c00290e0 <putchar_have_lock>
  release_console ();
c0029289:	e8 24 ff ff ff       	call   c00291b2 <release_console>
}
c002928e:	b8 00 00 00 00       	mov    $0x0,%eax
c0029293:	83 c4 08             	add    $0x8,%esp
c0029296:	5b                   	pop    %ebx
c0029297:	c3                   	ret    

c0029298 <putbuf>:
{
c0029298:	56                   	push   %esi
c0029299:	53                   	push   %ebx
c002929a:	83 ec 04             	sub    $0x4,%esp
c002929d:	8b 5c 24 10          	mov    0x10(%esp),%ebx
c00292a1:	8b 74 24 14          	mov    0x14(%esp),%esi
  acquire_console ();
c00292a5:	e8 c1 fe ff ff       	call   c002916b <acquire_console>
  while (n-- > 0)
c00292aa:	85 f6                	test   %esi,%esi
c00292ac:	74 10                	je     c00292be <putbuf+0x26>
c00292ae:	01 de                	add    %ebx,%esi
    putchar_have_lock (*buffer++);
c00292b0:	43                   	inc    %ebx
c00292b1:	0f b6 43 ff          	movzbl -0x1(%ebx),%eax
c00292b5:	e8 26 fe ff ff       	call   c00290e0 <putchar_have_lock>
  while (n-- > 0)
c00292ba:	39 de                	cmp    %ebx,%esi
c00292bc:	75 f2                	jne    c00292b0 <putbuf+0x18>
  release_console ();
c00292be:	e8 ef fe ff ff       	call   c00291b2 <release_console>
}
c00292c3:	83 c4 04             	add    $0x4,%esp
c00292c6:	5b                   	pop    %ebx
c00292c7:	5e                   	pop    %esi
c00292c8:	c3                   	ret    

c00292c9 <putchar>:
{
c00292c9:	83 ec 0c             	sub    $0xc,%esp
  acquire_console ();
c00292cc:	e8 9a fe ff ff       	call   c002916b <acquire_console>
  putchar_have_lock (c);
c00292d1:	0f b6 44 24 10       	movzbl 0x10(%esp),%eax
c00292d6:	e8 05 fe ff ff       	call   c00290e0 <putchar_have_lock>
  release_console ();
c00292db:	e8 d2 fe ff ff       	call   c00291b2 <release_console>
}
c00292e0:	8b 44 24 10          	mov    0x10(%esp),%eax
c00292e4:	83 c4 0c             	add    $0xc,%esp
c00292e7:	c3                   	ret    

c00292e8 <msg>:
/* Prints FORMAT as if with printf(),
   prefixing the output by the name of the test
   and following it with a new-line character. */
void
msg (const char *format, ...) 
{
c00292e8:	83 ec 14             	sub    $0x14,%esp
  va_list args;
  
  printf ("(%s) ", test_name);
c00292eb:	ff 35 70 84 03 c0    	pushl  0xc0038470
c00292f1:	68 78 ea 02 c0       	push   $0xc002ea78
c00292f6:	e8 66 ca ff ff       	call   c0025d61 <printf>
  va_start (args, format);
c00292fb:	8d 44 24 24          	lea    0x24(%esp),%eax
  vprintf (format, args);
c00292ff:	83 c4 08             	add    $0x8,%esp
c0029302:	50                   	push   %eax
c0029303:	ff 74 24 1c          	pushl  0x1c(%esp)
c0029307:	e8 1d ff ff ff       	call   c0029229 <vprintf>
  va_end (args);
  putchar ('\n');
c002930c:	c7 04 24 0a 00 00 00 	movl   $0xa,(%esp)
c0029313:	e8 b1 ff ff ff       	call   c00292c9 <putchar>
}
c0029318:	83 c4 1c             	add    $0x1c,%esp
c002931b:	c3                   	ret    

c002931c <run_test>:
{
c002931c:	56                   	push   %esi
c002931d:	53                   	push   %ebx
c002931e:	83 ec 04             	sub    $0x4,%esp
c0029321:	8b 74 24 10          	mov    0x10(%esp),%esi
  for (t = tests; t < tests + sizeof tests / sizeof *tests; t++)
c0029325:	bb 80 ca 02 c0       	mov    $0xc002ca80,%ebx
    if (!strcmp (name, t->name))
c002932a:	83 ec 08             	sub    $0x8,%esp
c002932d:	ff 33                	pushl  (%ebx)
c002932f:	56                   	push   %esi
c0029330:	e8 8f d8 ff ff       	call   c0026bc4 <strcmp>
c0029335:	83 c4 10             	add    $0x10,%esp
c0029338:	85 c0                	test   %eax,%eax
c002933a:	74 25                	je     c0029361 <run_test+0x45>
  for (t = tests; t < tests + sizeof tests / sizeof *tests; t++)
c002933c:	83 c3 08             	add    $0x8,%ebx
c002933f:	81 fb 58 cb 02 c0    	cmp    $0xc002cb58,%ebx
c0029345:	72 e3                	jb     c002932a <run_test+0xe>
  PANIC ("no test named \"%s\"", name);
c0029347:	83 ec 0c             	sub    $0xc,%esp
c002934a:	56                   	push   %esi
c002934b:	68 88 ea 02 c0       	push   $0xc002ea88
c0029350:	68 68 ca 02 c0       	push   $0xc002ca68
c0029355:	6a 3c                	push   $0x3c
c0029357:	68 9b ea 02 c0       	push   $0xc002ea9b
c002935c:	e8 ae e4 ff ff       	call   c002780f <debug_panic>
        test_name = name;
c0029361:	89 35 70 84 03 c0    	mov    %esi,0xc0038470
        msg ("begin");
c0029367:	83 ec 0c             	sub    $0xc,%esp
c002936a:	68 7e ea 02 c0       	push   $0xc002ea7e
c002936f:	e8 74 ff ff ff       	call   c00292e8 <msg>
        t->function ();
c0029374:	ff 53 04             	call   *0x4(%ebx)
        msg ("end");
c0029377:	c7 04 24 84 ea 02 c0 	movl   $0xc002ea84,(%esp)
c002937e:	e8 65 ff ff ff       	call   c00292e8 <msg>
        return;
c0029383:	83 c4 10             	add    $0x10,%esp
}
c0029386:	83 c4 04             	add    $0x4,%esp
c0029389:	5b                   	pop    %ebx
c002938a:	5e                   	pop    %esi
c002938b:	c3                   	ret    

c002938c <fail>:
   prefixing the output by the name of the test and FAIL:
   and following it with a new-line character,
   and then panics the kernel. */
void
fail (const char *format, ...) 
{
c002938c:	83 ec 14             	sub    $0x14,%esp
  va_list args;
  
  printf ("(%s) FAIL: ", test_name);
c002938f:	ff 35 70 84 03 c0    	pushl  0xc0038470
c0029395:	68 b7 ea 02 c0       	push   $0xc002eab7
c002939a:	e8 c2 c9 ff ff       	call   c0025d61 <printf>
  va_start (args, format);
c002939f:	8d 44 24 24          	lea    0x24(%esp),%eax
  vprintf (format, args);
c00293a3:	83 c4 08             	add    $0x8,%esp
c00293a6:	50                   	push   %eax
c00293a7:	ff 74 24 1c          	pushl  0x1c(%esp)
c00293ab:	e8 79 fe ff ff       	call   c0029229 <vprintf>
  va_end (args);
  putchar ('\n');
c00293b0:	c7 04 24 0a 00 00 00 	movl   $0xa,(%esp)
c00293b7:	e8 0d ff ff ff       	call   c00292c9 <putchar>

  PANIC ("test failed");
c00293bc:	68 c3 ea 02 c0       	push   $0xc002eac3
c00293c1:	68 60 ca 02 c0       	push   $0xc002ca60
c00293c6:	6a 5d                	push   $0x5d
c00293c8:	68 9b ea 02 c0       	push   $0xc002ea9b
c00293cd:	e8 3d e4 ff ff       	call   c002780f <debug_panic>

c00293d2 <pass>:
}

/* Prints a message indicating the current test passed. */
void
pass (void) 
{
c00293d2:	83 ec 14             	sub    $0x14,%esp
  printf ("(%s) PASS\n", test_name);
c00293d5:	ff 35 70 84 03 c0    	pushl  0xc0038470
c00293db:	68 cf ea 02 c0       	push   $0xc002eacf
c00293e0:	e8 7c c9 ff ff       	call   c0025d61 <printf>
}
c00293e5:	83 c4 1c             	add    $0x1c,%esp
c00293e8:	c3                   	ret    

c00293e9 <sleeper>:
}

/* Sleeper thread. */
static void
sleeper (void *t_) 
{
c00293e9:	55                   	push   %ebp
c00293ea:	57                   	push   %edi
c00293eb:	56                   	push   %esi
c00293ec:	53                   	push   %ebx
c00293ed:	83 ec 1c             	sub    $0x1c,%esp
c00293f0:	8b 6c 24 30          	mov    0x30(%esp),%ebp
  struct sleep_thread *t = t_;
  struct sleep_test *test = t->test;
c00293f4:	8b 5d 00             	mov    0x0(%ebp),%ebx
  int i;

  for (i = 1; i <= test->iterations; i++) 
c00293f7:	83 7b 08 00          	cmpl   $0x0,0x8(%ebx)
c00293fb:	7e 62                	jle    c002945f <sleeper+0x76>
c00293fd:	be 01 00 00 00       	mov    $0x1,%esi
    {
      int64_t sleep_until = test->start + i * t->duration;
      timer_sleep (sleep_until - timer_ticks ());
      lock_acquire (&test->output_lock);
c0029402:	8d 43 0c             	lea    0xc(%ebx),%eax
c0029405:	89 44 24 0c          	mov    %eax,0xc(%esp)
      int64_t sleep_until = test->start + i * t->duration;
c0029409:	89 f0                	mov    %esi,%eax
c002940b:	8b 4c 24 30          	mov    0x30(%esp),%ecx
c002940f:	0f af 41 08          	imul   0x8(%ecx),%eax
c0029413:	99                   	cltd   
c0029414:	03 03                	add    (%ebx),%eax
c0029416:	13 53 04             	adc    0x4(%ebx),%edx
c0029419:	89 c7                	mov    %eax,%edi
c002941b:	89 d5                	mov    %edx,%ebp
      timer_sleep (sleep_until - timer_ticks ());
c002941d:	e8 3d a0 ff ff       	call   c002345f <timer_ticks>
c0029422:	83 ec 08             	sub    $0x8,%esp
c0029425:	29 c7                	sub    %eax,%edi
c0029427:	19 d5                	sbb    %edx,%ebp
c0029429:	55                   	push   %ebp
c002942a:	57                   	push   %edi
c002942b:	e8 74 a0 ff ff       	call   c00234a4 <timer_sleep>
      lock_acquire (&test->output_lock);
c0029430:	8b 7c 24 1c          	mov    0x1c(%esp),%edi
c0029434:	89 3c 24             	mov    %edi,(%esp)
c0029437:	e8 fb 90 ff ff       	call   c0022537 <lock_acquire>
      *test->output_pos++ = t->id;
c002943c:	8b 43 24             	mov    0x24(%ebx),%eax
c002943f:	8d 50 04             	lea    0x4(%eax),%edx
c0029442:	89 53 24             	mov    %edx,0x24(%ebx)
c0029445:	8b 4c 24 40          	mov    0x40(%esp),%ecx
c0029449:	8b 51 04             	mov    0x4(%ecx),%edx
c002944c:	89 10                	mov    %edx,(%eax)
      lock_release (&test->output_lock);
c002944e:	89 3c 24             	mov    %edi,(%esp)
c0029451:	e8 06 92 ff ff       	call   c002265c <lock_release>
  for (i = 1; i <= test->iterations; i++) 
c0029456:	46                   	inc    %esi
c0029457:	83 c4 10             	add    $0x10,%esp
c002945a:	39 73 08             	cmp    %esi,0x8(%ebx)
c002945d:	7d aa                	jge    c0029409 <sleeper+0x20>
    }
}
c002945f:	83 c4 1c             	add    $0x1c,%esp
c0029462:	5b                   	pop    %ebx
c0029463:	5e                   	pop    %esi
c0029464:	5f                   	pop    %edi
c0029465:	5d                   	pop    %ebp
c0029466:	c3                   	ret    

c0029467 <test_sleep>:
{
c0029467:	55                   	push   %ebp
c0029468:	57                   	push   %edi
c0029469:	56                   	push   %esi
c002946a:	53                   	push   %ebx
c002946b:	83 ec 5c             	sub    $0x5c,%esp
c002946e:	89 04 24             	mov    %eax,(%esp)
c0029471:	89 54 24 0c          	mov    %edx,0xc(%esp)
  ASSERT (!thread_mlfqs);
c0029475:	80 3d ec 84 03 c0 00 	cmpb   $0x0,0xc00384ec
c002947c:	0f 85 63 01 00 00    	jne    c00295e5 <test_sleep+0x17e>
  msg ("Creating %d threads to sleep %d times each.", thread_cnt, iterations);
c0029482:	83 ec 04             	sub    $0x4,%esp
c0029485:	8b 7c 24 10          	mov    0x10(%esp),%edi
c0029489:	57                   	push   %edi
c002948a:	8b 74 24 08          	mov    0x8(%esp),%esi
c002948e:	56                   	push   %esi
c002948f:	68 f4 ec 02 c0       	push   $0xc002ecf4
c0029494:	e8 4f fe ff ff       	call   c00292e8 <msg>
  msg ("Thread 0 sleeps 10 ticks each time,");
c0029499:	c7 04 24 20 ed 02 c0 	movl   $0xc002ed20,(%esp)
c00294a0:	e8 43 fe ff ff       	call   c00292e8 <msg>
  msg ("thread 1 sleeps 20 ticks each time, and so on.");
c00294a5:	c7 04 24 44 ed 02 c0 	movl   $0xc002ed44,(%esp)
c00294ac:	e8 37 fe ff ff       	call   c00292e8 <msg>
  msg ("If successful, product of iteration count and");
c00294b1:	c7 04 24 74 ed 02 c0 	movl   $0xc002ed74,(%esp)
c00294b8:	e8 2b fe ff ff       	call   c00292e8 <msg>
  msg ("sleep duration will appear in nondescending order.");
c00294bd:	c7 04 24 a4 ed 02 c0 	movl   $0xc002eda4,(%esp)
c00294c4:	e8 1f fe ff ff       	call   c00292e8 <msg>
  threads = malloc (sizeof *threads * thread_cnt);
c00294c9:	89 f0                	mov    %esi,%eax
c00294cb:	c1 e0 04             	shl    $0x4,%eax
c00294ce:	89 04 24             	mov    %eax,(%esp)
c00294d1:	e8 ac 99 ff ff       	call   c0022e82 <malloc>
c00294d6:	89 c3                	mov    %eax,%ebx
c00294d8:	89 44 24 14          	mov    %eax,0x14(%esp)
  output = malloc (sizeof *output * iterations * thread_cnt * 2);
c00294dc:	8d 04 fd 00 00 00 00 	lea    0x0(,%edi,8),%eax
c00294e3:	0f af c6             	imul   %esi,%eax
c00294e6:	89 04 24             	mov    %eax,(%esp)
c00294e9:	e8 94 99 ff ff       	call   c0022e82 <malloc>
c00294ee:	89 44 24 18          	mov    %eax,0x18(%esp)
  if (threads == NULL || output == NULL)
c00294f2:	83 c4 10             	add    $0x10,%esp
c00294f5:	85 db                	test   %ebx,%ebx
c00294f7:	0f 84 06 01 00 00    	je     c0029603 <test_sleep+0x19c>
c00294fd:	85 c0                	test   %eax,%eax
c00294ff:	0f 84 fe 00 00 00    	je     c0029603 <test_sleep+0x19c>
  test.start = timer_ticks () + 100;
c0029505:	e8 55 9f ff ff       	call   c002345f <timer_ticks>
c002950a:	83 c0 64             	add    $0x64,%eax
c002950d:	83 d2 00             	adc    $0x0,%edx
c0029510:	89 44 24 28          	mov    %eax,0x28(%esp)
c0029514:	89 54 24 2c          	mov    %edx,0x2c(%esp)
  test.iterations = iterations;
c0029518:	8b 44 24 0c          	mov    0xc(%esp),%eax
c002951c:	89 44 24 30          	mov    %eax,0x30(%esp)
  lock_init (&test.output_lock);
c0029520:	83 ec 0c             	sub    $0xc,%esp
c0029523:	8d 44 24 40          	lea    0x40(%esp),%eax
c0029527:	50                   	push   %eax
c0029528:	e8 88 8f ff ff       	call   c00224b5 <lock_init>
  test.output_pos = output;
c002952d:	8b 44 24 18          	mov    0x18(%esp),%eax
c0029531:	89 44 24 5c          	mov    %eax,0x5c(%esp)
  for (i = 0; i < thread_cnt; i++)
c0029535:	83 c4 10             	add    $0x10,%esp
c0029538:	83 3c 24 00          	cmpl   $0x0,(%esp)
c002953c:	0f 8e 8a 01 00 00    	jle    c00296cc <test_sleep+0x265>
c0029542:	8b 5c 24 04          	mov    0x4(%esp),%ebx
c0029546:	ba 00 00 00 00       	mov    $0x0,%edx
      t->test = &test;
c002954b:	8d 6c 24 28          	lea    0x28(%esp),%ebp
      snprintf (name, sizeof name, "thread %d", i);
c002954f:	8d 7c 24 18          	lea    0x18(%esp),%edi
      t->test = &test;
c0029553:	89 2b                	mov    %ebp,(%ebx)
      t->id = i;
c0029555:	89 53 04             	mov    %edx,0x4(%ebx)
      t->duration = (i + 1) * 10;
c0029558:	8d 72 01             	lea    0x1(%edx),%esi
c002955b:	8d 04 b6             	lea    (%esi,%esi,4),%eax
c002955e:	01 c0                	add    %eax,%eax
c0029560:	89 43 08             	mov    %eax,0x8(%ebx)
      t->iterations = 0;
c0029563:	c7 43 0c 00 00 00 00 	movl   $0x0,0xc(%ebx)
      snprintf (name, sizeof name, "thread %d", i);
c002956a:	52                   	push   %edx
c002956b:	68 a6 ec 02 c0       	push   $0xc002eca6
c0029570:	6a 10                	push   $0x10
c0029572:	57                   	push   %edi
c0029573:	e8 75 cf ff ff       	call   c00264ed <snprintf>
      thread_create (name, PRI_DEFAULT, sleeper, t);
c0029578:	53                   	push   %ebx
c0029579:	68 e9 93 02 c0       	push   $0xc00293e9
c002957e:	6a 1f                	push   $0x1f
c0029580:	57                   	push   %edi
c0029581:	e8 b4 74 ff ff       	call   c0020a3a <thread_create>
c0029586:	83 c3 10             	add    $0x10,%ebx
  for (i = 0; i < thread_cnt; i++)
c0029589:	89 f2                	mov    %esi,%edx
c002958b:	83 c4 20             	add    $0x20,%esp
c002958e:	39 34 24             	cmp    %esi,(%esp)
c0029591:	75 c0                	jne    c0029553 <test_sleep+0xec>
  timer_sleep (100 + thread_cnt * iterations * 10 + 100);
c0029593:	83 ec 08             	sub    $0x8,%esp
c0029596:	0f af 74 24 14       	imul   0x14(%esp),%esi
c002959b:	8d 04 b6             	lea    (%esi,%esi,4),%eax
c002959e:	8d 84 00 c8 00 00 00 	lea    0xc8(%eax,%eax,1),%eax
c00295a5:	99                   	cltd   
c00295a6:	52                   	push   %edx
c00295a7:	50                   	push   %eax
c00295a8:	e8 f7 9e ff ff       	call   c00234a4 <timer_sleep>
  lock_acquire (&test.output_lock);
c00295ad:	83 c4 04             	add    $0x4,%esp
c00295b0:	8d 44 24 40          	lea    0x40(%esp),%eax
c00295b4:	50                   	push   %eax
c00295b5:	e8 7d 8f ff ff       	call   c0022537 <lock_acquire>
  for (op = output; op < test.output_pos; op++) 
c00295ba:	83 c4 10             	add    $0x10,%esp
c00295bd:	8b 44 24 08          	mov    0x8(%esp),%eax
c00295c1:	3b 44 24 4c          	cmp    0x4c(%esp),%eax
c00295c5:	0f 83 cc 00 00 00    	jae    c0029697 <test_sleep+0x230>
      ASSERT (*op >= 0 && *op < thread_cnt);
c00295cb:	8b 44 24 08          	mov    0x8(%esp),%eax
c00295cf:	8b 18                	mov    (%eax),%ebx
c00295d1:	85 db                	test   %ebx,%ebx
c00295d3:	78 44                	js     c0029619 <test_sleep+0x1b2>
c00295d5:	39 1c 24             	cmp    %ebx,(%esp)
c00295d8:	7e 3f                	jle    c0029619 <test_sleep+0x1b2>
c00295da:	8b 74 24 08          	mov    0x8(%esp),%esi
c00295de:	bd 00 00 00 00       	mov    $0x0,%ebp
c00295e3:	eb 78                	jmp    c002965d <test_sleep+0x1f6>
  ASSERT (!thread_mlfqs);
c00295e5:	83 ec 0c             	sub    $0xc,%esp
c00295e8:	68 98 ec 02 c0       	push   $0xc002ec98
c00295ed:	68 9f cd 02 c0       	push   $0xc002cd9f
c00295f2:	68 58 cb 02 c0       	push   $0xc002cb58
c00295f7:	6a 3c                	push   $0x3c
c00295f9:	68 d0 ec 02 c0       	push   $0xc002ecd0
c00295fe:	e8 0c e2 ff ff       	call   c002780f <debug_panic>
    PANIC ("couldn't allocate memory for test");
c0029603:	68 d8 ed 02 c0       	push   $0xc002edd8
c0029608:	68 58 cb 02 c0       	push   $0xc002cb58
c002960d:	6a 48                	push   $0x48
c002960f:	68 d0 ec 02 c0       	push   $0xc002ecd0
c0029614:	e8 f6 e1 ff ff       	call   c002780f <debug_panic>
      ASSERT (*op >= 0 && *op < thread_cnt);
c0029619:	83 ec 0c             	sub    $0xc,%esp
c002961c:	68 b0 ec 02 c0       	push   $0xc002ecb0
c0029621:	68 9f cd 02 c0       	push   $0xc002cd9f
c0029626:	68 58 cb 02 c0       	push   $0xc002cb58
c002962b:	6a 6e                	push   $0x6e
c002962d:	68 d0 ec 02 c0       	push   $0xc002ecd0
c0029632:	e8 d8 e1 ff ff       	call   c002780f <debug_panic>
        fail ("thread %d woke up out of order (%d > %d)!",
c0029637:	57                   	push   %edi
c0029638:	55                   	push   %ebp
c0029639:	ff 73 04             	pushl  0x4(%ebx)
c002963c:	68 30 ee 02 c0       	push   $0xc002ee30
c0029641:	e8 46 fd ff ff       	call   c002938c <fail>
c0029646:	83 c4 10             	add    $0x10,%esp
  for (op = output; op < test.output_pos; op++) 
c0029649:	83 c6 04             	add    $0x4,%esi
c002964c:	39 74 24 4c          	cmp    %esi,0x4c(%esp)
c0029650:	76 3f                	jbe    c0029691 <test_sleep+0x22a>
      ASSERT (*op >= 0 && *op < thread_cnt);
c0029652:	8b 1e                	mov    (%esi),%ebx
c0029654:	85 db                	test   %ebx,%ebx
c0029656:	78 c1                	js     c0029619 <test_sleep+0x1b2>
c0029658:	39 1c 24             	cmp    %ebx,(%esp)
c002965b:	7e bc                	jle    c0029619 <test_sleep+0x1b2>
      t = threads + *op;
c002965d:	c1 e3 04             	shl    $0x4,%ebx
c0029660:	03 5c 24 04          	add    0x4(%esp),%ebx
      new_prod = ++t->iterations * t->duration;
c0029664:	8b 43 0c             	mov    0xc(%ebx),%eax
c0029667:	40                   	inc    %eax
c0029668:	89 43 0c             	mov    %eax,0xc(%ebx)
c002966b:	8b 53 08             	mov    0x8(%ebx),%edx
c002966e:	89 c7                	mov    %eax,%edi
c0029670:	0f af fa             	imul   %edx,%edi
      msg ("thread %d: duration=%d, iteration=%d, product=%d",
c0029673:	83 ec 0c             	sub    $0xc,%esp
c0029676:	57                   	push   %edi
c0029677:	50                   	push   %eax
c0029678:	52                   	push   %edx
c0029679:	ff 73 04             	pushl  0x4(%ebx)
c002967c:	68 fc ed 02 c0       	push   $0xc002edfc
c0029681:	e8 62 fc ff ff       	call   c00292e8 <msg>
      if (new_prod >= product)
c0029686:	83 c4 20             	add    $0x20,%esp
c0029689:	39 ef                	cmp    %ebp,%edi
c002968b:	7c aa                	jl     c0029637 <test_sleep+0x1d0>
        product = new_prod;
c002968d:	89 fd                	mov    %edi,%ebp
c002968f:	eb b8                	jmp    c0029649 <test_sleep+0x1e2>
  for (i = 0; i < thread_cnt; i++)
c0029691:	83 3c 24 00          	cmpl   $0x0,(%esp)
c0029695:	7e 71                	jle    c0029708 <test_sleep+0x2a1>
c0029697:	8b 44 24 04          	mov    0x4(%esp),%eax
c002969b:	8d 70 0c             	lea    0xc(%eax),%esi
        product = new_prod;
c002969e:	bb 00 00 00 00       	mov    $0x0,%ebx
c00296a3:	8b 2c 24             	mov    (%esp),%ebp
c00296a6:	8b 7c 24 0c          	mov    0xc(%esp),%edi
c00296aa:	eb 08                	jmp    c00296b4 <test_sleep+0x24d>
  for (i = 0; i < thread_cnt; i++)
c00296ac:	43                   	inc    %ebx
c00296ad:	83 c6 10             	add    $0x10,%esi
c00296b0:	39 dd                	cmp    %ebx,%ebp
c00296b2:	7e 54                	jle    c0029708 <test_sleep+0x2a1>
    if (threads[i].iterations != iterations)
c00296b4:	8b 06                	mov    (%esi),%eax
c00296b6:	39 c7                	cmp    %eax,%edi
c00296b8:	74 f2                	je     c00296ac <test_sleep+0x245>
      fail ("thread %d woke up %d times instead of %d",
c00296ba:	57                   	push   %edi
c00296bb:	50                   	push   %eax
c00296bc:	53                   	push   %ebx
c00296bd:	68 5c ee 02 c0       	push   $0xc002ee5c
c00296c2:	e8 c5 fc ff ff       	call   c002938c <fail>
c00296c7:	83 c4 10             	add    $0x10,%esp
c00296ca:	eb e0                	jmp    c00296ac <test_sleep+0x245>
  timer_sleep (100 + thread_cnt * iterations * 10 + 100);
c00296cc:	83 ec 08             	sub    $0x8,%esp
c00296cf:	8b 44 24 08          	mov    0x8(%esp),%eax
c00296d3:	0f af 44 24 14       	imul   0x14(%esp),%eax
c00296d8:	8d 04 80             	lea    (%eax,%eax,4),%eax
c00296db:	8d 84 00 c8 00 00 00 	lea    0xc8(%eax,%eax,1),%eax
c00296e2:	99                   	cltd   
c00296e3:	52                   	push   %edx
c00296e4:	50                   	push   %eax
c00296e5:	e8 ba 9d ff ff       	call   c00234a4 <timer_sleep>
  lock_acquire (&test.output_lock);
c00296ea:	83 c4 04             	add    $0x4,%esp
c00296ed:	8d 44 24 40          	lea    0x40(%esp),%eax
c00296f1:	50                   	push   %eax
c00296f2:	e8 40 8e ff ff       	call   c0022537 <lock_acquire>
  for (op = output; op < test.output_pos; op++) 
c00296f7:	83 c4 10             	add    $0x10,%esp
c00296fa:	8b 44 24 08          	mov    0x8(%esp),%eax
c00296fe:	3b 44 24 4c          	cmp    0x4c(%esp),%eax
c0029702:	0f 82 c3 fe ff ff    	jb     c00295cb <test_sleep+0x164>
  lock_release (&test.output_lock);
c0029708:	83 ec 0c             	sub    $0xc,%esp
c002970b:	8d 44 24 40          	lea    0x40(%esp),%eax
c002970f:	50                   	push   %eax
c0029710:	e8 47 8f ff ff       	call   c002265c <lock_release>
  free (output);
c0029715:	83 c4 04             	add    $0x4,%esp
c0029718:	ff 74 24 14          	pushl  0x14(%esp)
c002971c:	e8 02 99 ff ff       	call   c0023023 <free>
  free (threads);
c0029721:	83 c4 04             	add    $0x4,%esp
c0029724:	ff 74 24 10          	pushl  0x10(%esp)
c0029728:	e8 f6 98 ff ff       	call   c0023023 <free>
}
c002972d:	83 c4 10             	add    $0x10,%esp
c0029730:	83 c4 5c             	add    $0x5c,%esp
c0029733:	5b                   	pop    %ebx
c0029734:	5e                   	pop    %esi
c0029735:	5f                   	pop    %edi
c0029736:	5d                   	pop    %ebp
c0029737:	c3                   	ret    

c0029738 <test_alarm_single>:
{
c0029738:	83 ec 0c             	sub    $0xc,%esp
  test_sleep (5, 1);
c002973b:	ba 01 00 00 00       	mov    $0x1,%edx
c0029740:	b8 05 00 00 00       	mov    $0x5,%eax
c0029745:	e8 1d fd ff ff       	call   c0029467 <test_sleep>
}
c002974a:	83 c4 0c             	add    $0xc,%esp
c002974d:	c3                   	ret    

c002974e <test_alarm_multiple>:
{
c002974e:	83 ec 0c             	sub    $0xc,%esp
  test_sleep (5, 7);
c0029751:	ba 07 00 00 00       	mov    $0x7,%edx
c0029756:	b8 05 00 00 00       	mov    $0x5,%eax
c002975b:	e8 07 fd ff ff       	call   c0029467 <test_sleep>
}
c0029760:	83 c4 0c             	add    $0xc,%esp
c0029763:	c3                   	ret    

c0029764 <sleeper>:
}

/* Sleeper thread. */
static void
sleeper (void *test_) 
{
c0029764:	55                   	push   %ebp
c0029765:	57                   	push   %edi
c0029766:	56                   	push   %esi
c0029767:	53                   	push   %ebx
c0029768:	83 ec 14             	sub    $0x14,%esp
c002976b:	8b 5c 24 28          	mov    0x28(%esp),%ebx
  struct sleep_test *test = test_;
  int i;

  /* Make sure we're at the beginning of a timer tick. */
  timer_sleep (1);
c002976f:	6a 00                	push   $0x0
c0029771:	6a 01                	push   $0x1
c0029773:	e8 2c 9d ff ff       	call   c00234a4 <timer_sleep>

  for (i = 1; i <= test->iterations; i++) 
c0029778:	83 c4 10             	add    $0x10,%esp
c002977b:	83 7b 08 00          	cmpl   $0x0,0x8(%ebx)
c002977f:	7e 49                	jle    c00297ca <sleeper+0x66>
c0029781:	bd 01 00 00 00       	mov    $0x1,%ebp
    {
      int64_t sleep_until = test->start + i * 10;
c0029786:	8d 44 ad 00          	lea    0x0(%ebp,%ebp,4),%eax
c002978a:	8d 34 00             	lea    (%eax,%eax,1),%esi
c002978d:	89 f7                	mov    %esi,%edi
c002978f:	c1 ff 1f             	sar    $0x1f,%edi
c0029792:	03 33                	add    (%ebx),%esi
c0029794:	13 7b 04             	adc    0x4(%ebx),%edi
      timer_sleep (sleep_until - timer_ticks ());
c0029797:	e8 c3 9c ff ff       	call   c002345f <timer_ticks>
c002979c:	83 ec 08             	sub    $0x8,%esp
c002979f:	29 c6                	sub    %eax,%esi
c00297a1:	19 d7                	sbb    %edx,%edi
c00297a3:	57                   	push   %edi
c00297a4:	56                   	push   %esi
c00297a5:	e8 fa 9c ff ff       	call   c00234a4 <timer_sleep>
      *test->output_pos++ = timer_ticks () - test->start;
c00297aa:	8b 73 0c             	mov    0xc(%ebx),%esi
c00297ad:	8d 46 04             	lea    0x4(%esi),%eax
c00297b0:	89 43 0c             	mov    %eax,0xc(%ebx)
c00297b3:	e8 a7 9c ff ff       	call   c002345f <timer_ticks>
c00297b8:	2b 03                	sub    (%ebx),%eax
c00297ba:	89 06                	mov    %eax,(%esi)
      thread_yield ();
c00297bc:	e8 43 78 ff ff       	call   c0021004 <thread_yield>
  for (i = 1; i <= test->iterations; i++) 
c00297c1:	45                   	inc    %ebp
c00297c2:	83 c4 10             	add    $0x10,%esp
c00297c5:	39 6b 08             	cmp    %ebp,0x8(%ebx)
c00297c8:	7d bc                	jge    c0029786 <sleeper+0x22>
    }
}
c00297ca:	83 c4 0c             	add    $0xc,%esp
c00297cd:	5b                   	pop    %ebx
c00297ce:	5e                   	pop    %esi
c00297cf:	5f                   	pop    %edi
c00297d0:	5d                   	pop    %ebp
c00297d1:	c3                   	ret    

c00297d2 <test_alarm_simultaneous>:
{
c00297d2:	55                   	push   %ebp
c00297d3:	57                   	push   %edi
c00297d4:	56                   	push   %esi
c00297d5:	53                   	push   %ebx
c00297d6:	83 ec 2c             	sub    $0x2c,%esp
  ASSERT (!thread_mlfqs);
c00297d9:	80 3d ec 84 03 c0 00 	cmpb   $0x0,0xc00384ec
c00297e0:	0f 85 17 01 00 00    	jne    c00298fd <test_alarm_simultaneous+0x12b>
  msg ("Creating %d threads to sleep %d times each.", thread_cnt, iterations);
c00297e6:	83 ec 04             	sub    $0x4,%esp
c00297e9:	6a 05                	push   $0x5
c00297eb:	6a 03                	push   $0x3
c00297ed:	68 f4 ec 02 c0       	push   $0xc002ecf4
c00297f2:	e8 f1 fa ff ff       	call   c00292e8 <msg>
  msg ("Each thread sleeps 10 ticks each time.");
c00297f7:	c7 04 24 b4 ee 02 c0 	movl   $0xc002eeb4,(%esp)
c00297fe:	e8 e5 fa ff ff       	call   c00292e8 <msg>
  msg ("Within an iteration, all threads should wake up on the same tick.");
c0029803:	c7 04 24 dc ee 02 c0 	movl   $0xc002eedc,(%esp)
c002980a:	e8 d9 fa ff ff       	call   c00292e8 <msg>
  output = malloc (sizeof *output * iterations * thread_cnt * 2);
c002980f:	c7 04 24 78 00 00 00 	movl   $0x78,(%esp)
c0029816:	e8 67 96 ff ff       	call   c0022e82 <malloc>
c002981b:	89 c6                	mov    %eax,%esi
  if (output == NULL)
c002981d:	83 c4 10             	add    $0x10,%esp
c0029820:	85 c0                	test   %eax,%eax
c0029822:	0f 84 f3 00 00 00    	je     c002991b <test_alarm_simultaneous+0x149>
  test.start = timer_ticks () + 100;
c0029828:	e8 32 9c ff ff       	call   c002345f <timer_ticks>
c002982d:	83 c0 64             	add    $0x64,%eax
c0029830:	83 d2 00             	adc    $0x0,%edx
c0029833:	89 04 24             	mov    %eax,(%esp)
c0029836:	89 54 24 04          	mov    %edx,0x4(%esp)
  test.iterations = iterations;
c002983a:	c7 44 24 08 05 00 00 	movl   $0x5,0x8(%esp)
c0029841:	00 
  test.output_pos = output;
c0029842:	89 74 24 0c          	mov    %esi,0xc(%esp)
  for (i = 0; i < thread_cnt; i++)
c0029846:	bb 00 00 00 00       	mov    $0x0,%ebx
      snprintf (name, sizeof name, "thread %d", i);
c002984b:	8d 7c 24 10          	lea    0x10(%esp),%edi
      thread_create (name, PRI_DEFAULT, sleeper, &test);
c002984f:	89 e5                	mov    %esp,%ebp
      snprintf (name, sizeof name, "thread %d", i);
c0029851:	53                   	push   %ebx
c0029852:	68 a6 ec 02 c0       	push   $0xc002eca6
c0029857:	6a 10                	push   $0x10
c0029859:	57                   	push   %edi
c002985a:	e8 8e cc ff ff       	call   c00264ed <snprintf>
      thread_create (name, PRI_DEFAULT, sleeper, &test);
c002985f:	55                   	push   %ebp
c0029860:	68 64 97 02 c0       	push   $0xc0029764
c0029865:	6a 1f                	push   $0x1f
c0029867:	57                   	push   %edi
c0029868:	e8 cd 71 ff ff       	call   c0020a3a <thread_create>
  for (i = 0; i < thread_cnt; i++)
c002986d:	43                   	inc    %ebx
c002986e:	83 c4 20             	add    $0x20,%esp
c0029871:	83 fb 03             	cmp    $0x3,%ebx
c0029874:	75 db                	jne    c0029851 <test_alarm_simultaneous+0x7f>
  timer_sleep (100 + iterations * 10 + 100);
c0029876:	83 ec 08             	sub    $0x8,%esp
c0029879:	6a 00                	push   $0x0
c002987b:	68 fa 00 00 00       	push   $0xfa
c0029880:	e8 1f 9c ff ff       	call   c00234a4 <timer_sleep>
  msg ("iteration 0, thread 0: woke up after %d ticks", output[0]);
c0029885:	83 c4 08             	add    $0x8,%esp
c0029888:	ff 36                	pushl  (%esi)
c002988a:	68 20 ef 02 c0       	push   $0xc002ef20
c002988f:	e8 54 fa ff ff       	call   c00292e8 <msg>
  for (i = 1; i < test.output_pos - output; i++) 
c0029894:	89 f5                	mov    %esi,%ebp
c0029896:	8b 44 24 1c          	mov    0x1c(%esp),%eax
c002989a:	29 f0                	sub    %esi,%eax
c002989c:	83 c4 10             	add    $0x10,%esp
c002989f:	83 f8 07             	cmp    $0x7,%eax
c00298a2:	7e 48                	jle    c00298ec <test_alarm_simultaneous+0x11a>
c00298a4:	bb 01 00 00 00       	mov    $0x1,%ebx
    msg ("iteration %d, thread %d: woke up %d ticks later",
c00298a9:	bf 03 00 00 00       	mov    $0x3,%edi
c00298ae:	8b 04 9e             	mov    (%esi,%ebx,4),%eax
c00298b1:	2b 44 9e fc          	sub    -0x4(%esi,%ebx,4),%eax
c00298b5:	50                   	push   %eax
c00298b6:	89 d8                	mov    %ebx,%eax
c00298b8:	99                   	cltd   
c00298b9:	f7 ff                	idiv   %edi
c00298bb:	52                   	push   %edx
c00298bc:	b8 56 55 55 55       	mov    $0x55555556,%eax
c00298c1:	f7 eb                	imul   %ebx
c00298c3:	89 d1                	mov    %edx,%ecx
c00298c5:	89 d8                	mov    %ebx,%eax
c00298c7:	c1 f8 1f             	sar    $0x1f,%eax
c00298ca:	89 c2                	mov    %eax,%edx
c00298cc:	89 c8                	mov    %ecx,%eax
c00298ce:	29 d0                	sub    %edx,%eax
c00298d0:	50                   	push   %eax
c00298d1:	68 50 ef 02 c0       	push   $0xc002ef50
c00298d6:	e8 0d fa ff ff       	call   c00292e8 <msg>
  for (i = 1; i < test.output_pos - output; i++) 
c00298db:	43                   	inc    %ebx
c00298dc:	8b 44 24 1c          	mov    0x1c(%esp),%eax
c00298e0:	29 e8                	sub    %ebp,%eax
c00298e2:	c1 f8 02             	sar    $0x2,%eax
c00298e5:	83 c4 10             	add    $0x10,%esp
c00298e8:	39 c3                	cmp    %eax,%ebx
c00298ea:	7c c2                	jl     c00298ae <test_alarm_simultaneous+0xdc>
  free (output);
c00298ec:	83 ec 0c             	sub    $0xc,%esp
c00298ef:	56                   	push   %esi
c00298f0:	e8 2e 97 ff ff       	call   c0023023 <free>
}
c00298f5:	83 c4 3c             	add    $0x3c,%esp
c00298f8:	5b                   	pop    %ebx
c00298f9:	5e                   	pop    %esi
c00298fa:	5f                   	pop    %edi
c00298fb:	5d                   	pop    %ebp
c00298fc:	c3                   	ret    
  ASSERT (!thread_mlfqs);
c00298fd:	83 ec 0c             	sub    $0xc,%esp
c0029900:	68 98 ec 02 c0       	push   $0xc002ec98
c0029905:	68 9f cd 02 c0       	push   $0xc002cd9f
c002990a:	68 64 cb 02 c0       	push   $0xc002cb64
c002990f:	6a 28                	push   $0x28
c0029911:	68 88 ee 02 c0       	push   $0xc002ee88
c0029916:	e8 f4 de ff ff       	call   c002780f <debug_panic>
    PANIC ("couldn't allocate memory for test");
c002991b:	68 d8 ed 02 c0       	push   $0xc002edd8
c0029920:	68 64 cb 02 c0       	push   $0xc002cb64
c0029925:	6a 31                	push   $0x31
c0029927:	68 88 ee 02 c0       	push   $0xc002ee88
c002992c:	e8 de de ff ff       	call   c002780f <debug_panic>

c0029931 <alarm_priority_thread>:
    sema_down (&wait_sema);
}

static void
alarm_priority_thread (void *aux UNUSED) 
{
c0029931:	57                   	push   %edi
c0029932:	56                   	push   %esi
c0029933:	83 ec 04             	sub    $0x4,%esp
  /* Busy-wait until the current time changes. */
  int64_t start_time = timer_ticks ();
c0029936:	e8 24 9b ff ff       	call   c002345f <timer_ticks>
c002993b:	89 c6                	mov    %eax,%esi
c002993d:	89 d7                	mov    %edx,%edi
  while (timer_elapsed (start_time) == 0)
c002993f:	83 ec 08             	sub    $0x8,%esp
c0029942:	57                   	push   %edi
c0029943:	56                   	push   %esi
c0029944:	e8 3f 9b ff ff       	call   c0023488 <timer_elapsed>
c0029949:	83 c4 10             	add    $0x10,%esp
c002994c:	09 c2                	or     %eax,%edx
c002994e:	74 ef                	je     c002993f <alarm_priority_thread+0xe>
    continue;

  /* Now we know we're at the very beginning of a timer tick, so
     we can call timer_sleep() without worrying about races
     between checking the time and a timer interrupt. */
  timer_sleep (wake_time - timer_ticks ());
c0029950:	8b 35 90 84 03 c0    	mov    0xc0038490,%esi
c0029956:	8b 3d 94 84 03 c0    	mov    0xc0038494,%edi
c002995c:	e8 fe 9a ff ff       	call   c002345f <timer_ticks>
c0029961:	83 ec 08             	sub    $0x8,%esp
c0029964:	29 c6                	sub    %eax,%esi
c0029966:	19 d7                	sbb    %edx,%edi
c0029968:	57                   	push   %edi
c0029969:	56                   	push   %esi
c002996a:	e8 35 9b ff ff       	call   c00234a4 <timer_sleep>

  /* Print a message on wake-up. */
  msg ("Thread %s woke up.", thread_name ());
c002996f:	e8 85 72 ff ff       	call   c0020bf9 <thread_name>
c0029974:	83 c4 08             	add    $0x8,%esp
c0029977:	50                   	push   %eax
c0029978:	68 80 ef 02 c0       	push   $0xc002ef80
c002997d:	e8 66 f9 ff ff       	call   c00292e8 <msg>

  sema_up (&wait_sema);
c0029982:	c7 04 24 78 84 03 c0 	movl   $0xc0038478,(%esp)
c0029989:	e8 14 8a ff ff       	call   c00223a2 <sema_up>
}
c002998e:	83 c4 14             	add    $0x14,%esp
c0029991:	5e                   	pop    %esi
c0029992:	5f                   	pop    %edi
c0029993:	c3                   	ret    

c0029994 <test_alarm_priority>:
{
c0029994:	55                   	push   %ebp
c0029995:	57                   	push   %edi
c0029996:	56                   	push   %esi
c0029997:	53                   	push   %ebx
c0029998:	83 ec 1c             	sub    $0x1c,%esp
  ASSERT (!thread_mlfqs);
c002999b:	80 3d ec 84 03 c0 00 	cmpb   $0x0,0xc00384ec
c00299a2:	0f 85 94 00 00 00    	jne    c0029a3c <test_alarm_priority+0xa8>
  wake_time = timer_ticks () + 5 * TIMER_FREQ;
c00299a8:	e8 b2 9a ff ff       	call   c002345f <timer_ticks>
c00299ad:	05 f4 01 00 00       	add    $0x1f4,%eax
c00299b2:	83 d2 00             	adc    $0x0,%edx
c00299b5:	a3 90 84 03 c0       	mov    %eax,0xc0038490
c00299ba:	89 15 94 84 03 c0    	mov    %edx,0xc0038494
  sema_init (&wait_sema, 0);
c00299c0:	83 ec 08             	sub    $0x8,%esp
c00299c3:	6a 00                	push   $0x0
c00299c5:	68 78 84 03 c0       	push   $0xc0038478
c00299ca:	e8 b3 88 ff ff       	call   c0022282 <sema_init>
c00299cf:	83 c4 10             	add    $0x10,%esp
c00299d2:	bb 05 00 00 00       	mov    $0x5,%ebx
      int priority = PRI_DEFAULT - (i + 5) % 10 - 1;
c00299d7:	bd 0a 00 00 00       	mov    $0xa,%ebp
      snprintf (name, sizeof name, "priority %d", priority);
c00299dc:	89 e7                	mov    %esp,%edi
      int priority = PRI_DEFAULT - (i + 5) % 10 - 1;
c00299de:	89 d8                	mov    %ebx,%eax
c00299e0:	99                   	cltd   
c00299e1:	f7 fd                	idiv   %ebp
c00299e3:	be 1e 00 00 00       	mov    $0x1e,%esi
c00299e8:	29 d6                	sub    %edx,%esi
      snprintf (name, sizeof name, "priority %d", priority);
c00299ea:	56                   	push   %esi
c00299eb:	68 93 ef 02 c0       	push   $0xc002ef93
c00299f0:	6a 10                	push   $0x10
c00299f2:	57                   	push   %edi
c00299f3:	e8 f5 ca ff ff       	call   c00264ed <snprintf>
      thread_create (name, priority, alarm_priority_thread, NULL);
c00299f8:	6a 00                	push   $0x0
c00299fa:	68 31 99 02 c0       	push   $0xc0029931
c00299ff:	56                   	push   %esi
c0029a00:	57                   	push   %edi
c0029a01:	e8 34 70 ff ff       	call   c0020a3a <thread_create>
c0029a06:	43                   	inc    %ebx
  for (i = 0; i < 10; i++) 
c0029a07:	83 c4 20             	add    $0x20,%esp
c0029a0a:	83 fb 0f             	cmp    $0xf,%ebx
c0029a0d:	75 cf                	jne    c00299de <test_alarm_priority+0x4a>
  thread_set_priority (PRI_MIN);
c0029a0f:	83 ec 0c             	sub    $0xc,%esp
c0029a12:	6a 00                	push   $0x0
c0029a14:	e8 fa 72 ff ff       	call   c0020d13 <thread_set_priority>
c0029a19:	83 c4 10             	add    $0x10,%esp
c0029a1c:	bb 0a 00 00 00       	mov    $0xa,%ebx
    sema_down (&wait_sema);
c0029a21:	83 ec 0c             	sub    $0xc,%esp
c0029a24:	68 78 84 03 c0       	push   $0xc0038478
c0029a29:	e8 93 88 ff ff       	call   c00222c1 <sema_down>
  for (i = 0; i < 10; i++)
c0029a2e:	83 c4 10             	add    $0x10,%esp
c0029a31:	4b                   	dec    %ebx
c0029a32:	75 ed                	jne    c0029a21 <test_alarm_priority+0x8d>
}
c0029a34:	83 c4 1c             	add    $0x1c,%esp
c0029a37:	5b                   	pop    %ebx
c0029a38:	5e                   	pop    %esi
c0029a39:	5f                   	pop    %edi
c0029a3a:	5d                   	pop    %ebp
c0029a3b:	c3                   	ret    
  ASSERT (!thread_mlfqs);
c0029a3c:	83 ec 0c             	sub    $0xc,%esp
c0029a3f:	68 98 ec 02 c0       	push   $0xc002ec98
c0029a44:	68 9f cd 02 c0       	push   $0xc002cd9f
c0029a49:	68 70 cb 02 c0       	push   $0xc002cb70
c0029a4e:	6a 16                	push   $0x16
c0029a50:	68 a0 ef 02 c0       	push   $0xc002efa0
c0029a55:	e8 b5 dd ff ff       	call   c002780f <debug_panic>

c0029a5a <test_alarm_zero>:
#include "threads/thread.h"
#include "devices/timer.h"

void
test_alarm_zero (void) 
{
c0029a5a:	83 ec 14             	sub    $0x14,%esp
  timer_sleep (0);
c0029a5d:	6a 00                	push   $0x0
c0029a5f:	6a 00                	push   $0x0
c0029a61:	e8 3e 9a ff ff       	call   c00234a4 <timer_sleep>
  pass ();
c0029a66:	e8 67 f9 ff ff       	call   c00293d2 <pass>
}
c0029a6b:	83 c4 1c             	add    $0x1c,%esp
c0029a6e:	c3                   	ret    

c0029a6f <test_alarm_negative>:
#include "threads/thread.h"
#include "devices/timer.h"

void
test_alarm_negative (void) 
{
c0029a6f:	83 ec 14             	sub    $0x14,%esp
  timer_sleep (-100);
c0029a72:	6a ff                	push   $0xffffffff
c0029a74:	6a 9c                	push   $0xffffff9c
c0029a76:	e8 29 9a ff ff       	call   c00234a4 <timer_sleep>
  pass ();
c0029a7b:	e8 52 f9 ff ff       	call   c00293d2 <pass>
}
c0029a80:	83 c4 1c             	add    $0x1c,%esp
c0029a83:	c3                   	ret    

c0029a84 <changing_thread>:
  msg ("Thread 2 should have just exited.");
}

static void
changing_thread (void *aux UNUSED) 
{
c0029a84:	83 ec 18             	sub    $0x18,%esp
  msg ("Thread 2 now lowering priority.");
c0029a87:	68 c8 ef 02 c0       	push   $0xc002efc8
c0029a8c:	e8 57 f8 ff ff       	call   c00292e8 <msg>
  thread_set_priority (PRI_DEFAULT - 1);
c0029a91:	c7 04 24 1e 00 00 00 	movl   $0x1e,(%esp)
c0029a98:	e8 76 72 ff ff       	call   c0020d13 <thread_set_priority>
  msg ("Thread 2 exiting.");
c0029a9d:	c7 04 24 86 f0 02 c0 	movl   $0xc002f086,(%esp)
c0029aa4:	e8 3f f8 ff ff       	call   c00292e8 <msg>
}
c0029aa9:	83 c4 1c             	add    $0x1c,%esp
c0029aac:	c3                   	ret    

c0029aad <test_priority_change>:
{
c0029aad:	83 ec 0c             	sub    $0xc,%esp
  ASSERT (!thread_mlfqs);
c0029ab0:	80 3d ec 84 03 c0 00 	cmpb   $0x0,0xc00384ec
c0029ab7:	75 49                	jne    c0029b02 <test_priority_change+0x55>
  msg ("Creating a high-priority thread 2.");
c0029ab9:	83 ec 0c             	sub    $0xc,%esp
c0029abc:	68 10 f0 02 c0       	push   $0xc002f010
c0029ac1:	e8 22 f8 ff ff       	call   c00292e8 <msg>
  thread_create ("thread 2", PRI_DEFAULT + 1, changing_thread, NULL);
c0029ac6:	6a 00                	push   $0x0
c0029ac8:	68 84 9a 02 c0       	push   $0xc0029a84
c0029acd:	6a 20                	push   $0x20
c0029acf:	68 98 f0 02 c0       	push   $0xc002f098
c0029ad4:	e8 61 6f ff ff       	call   c0020a3a <thread_create>
  msg ("Thread 2 should have just lowered its priority.");
c0029ad9:	83 c4 14             	add    $0x14,%esp
c0029adc:	68 34 f0 02 c0       	push   $0xc002f034
c0029ae1:	e8 02 f8 ff ff       	call   c00292e8 <msg>
  thread_set_priority (PRI_DEFAULT - 2);
c0029ae6:	c7 04 24 1d 00 00 00 	movl   $0x1d,(%esp)
c0029aed:	e8 21 72 ff ff       	call   c0020d13 <thread_set_priority>
  msg ("Thread 2 should have just exited.");
c0029af2:	c7 04 24 64 f0 02 c0 	movl   $0xc002f064,(%esp)
c0029af9:	e8 ea f7 ff ff       	call   c00292e8 <msg>
}
c0029afe:	83 c4 1c             	add    $0x1c,%esp
c0029b01:	c3                   	ret    
  ASSERT (!thread_mlfqs);
c0029b02:	83 ec 0c             	sub    $0xc,%esp
c0029b05:	68 98 ec 02 c0       	push   $0xc002ec98
c0029b0a:	68 9f cd 02 c0       	push   $0xc002cd9f
c0029b0f:	68 84 cb 02 c0       	push   $0xc002cb84
c0029b14:	6a 10                	push   $0x10
c0029b16:	68 e8 ef 02 c0       	push   $0xc002efe8
c0029b1b:	e8 ef dc ff ff       	call   c002780f <debug_panic>

c0029b20 <acquire2_thread_func>:
  msg ("acquire1: done");
}

static void
acquire2_thread_func (void *lock_) 
{
c0029b20:	53                   	push   %ebx
c0029b21:	83 ec 14             	sub    $0x14,%esp
c0029b24:	8b 5c 24 1c          	mov    0x1c(%esp),%ebx
  struct lock *lock = lock_;

  lock_acquire (lock);
c0029b28:	53                   	push   %ebx
c0029b29:	e8 09 8a ff ff       	call   c0022537 <lock_acquire>
  msg ("acquire2: got the lock");
c0029b2e:	c7 04 24 a1 f0 02 c0 	movl   $0xc002f0a1,(%esp)
c0029b35:	e8 ae f7 ff ff       	call   c00292e8 <msg>
  lock_release (lock);
c0029b3a:	89 1c 24             	mov    %ebx,(%esp)
c0029b3d:	e8 1a 8b ff ff       	call   c002265c <lock_release>
  msg ("acquire2: done");
c0029b42:	c7 04 24 b8 f0 02 c0 	movl   $0xc002f0b8,(%esp)
c0029b49:	e8 9a f7 ff ff       	call   c00292e8 <msg>
}
c0029b4e:	83 c4 18             	add    $0x18,%esp
c0029b51:	5b                   	pop    %ebx
c0029b52:	c3                   	ret    

c0029b53 <acquire1_thread_func>:
{
c0029b53:	53                   	push   %ebx
c0029b54:	83 ec 14             	sub    $0x14,%esp
c0029b57:	8b 5c 24 1c          	mov    0x1c(%esp),%ebx
  lock_acquire (lock);
c0029b5b:	53                   	push   %ebx
c0029b5c:	e8 d6 89 ff ff       	call   c0022537 <lock_acquire>
  msg ("acquire1: got the lock");
c0029b61:	c7 04 24 c7 f0 02 c0 	movl   $0xc002f0c7,(%esp)
c0029b68:	e8 7b f7 ff ff       	call   c00292e8 <msg>
  lock_release (lock);
c0029b6d:	89 1c 24             	mov    %ebx,(%esp)
c0029b70:	e8 e7 8a ff ff       	call   c002265c <lock_release>
  msg ("acquire1: done");
c0029b75:	c7 04 24 de f0 02 c0 	movl   $0xc002f0de,(%esp)
c0029b7c:	e8 67 f7 ff ff       	call   c00292e8 <msg>
}
c0029b81:	83 c4 18             	add    $0x18,%esp
c0029b84:	5b                   	pop    %ebx
c0029b85:	c3                   	ret    

c0029b86 <test_priority_donate_one>:
{
c0029b86:	53                   	push   %ebx
c0029b87:	83 ec 28             	sub    $0x28,%esp
  ASSERT (!thread_mlfqs);
c0029b8a:	80 3d ec 84 03 c0 00 	cmpb   $0x0,0xc00384ec
c0029b91:	0f 85 9c 00 00 00    	jne    c0029c33 <test_priority_donate_one+0xad>
  ASSERT (thread_get_priority () == PRI_DEFAULT);
c0029b97:	e8 8a 71 ff ff       	call   c0020d26 <thread_get_priority>
c0029b9c:	83 f8 1f             	cmp    $0x1f,%eax
c0029b9f:	0f 85 ac 00 00 00    	jne    c0029c51 <test_priority_donate_one+0xcb>
  lock_init (&lock);
c0029ba5:	83 ec 0c             	sub    $0xc,%esp
c0029ba8:	8d 5c 24 14          	lea    0x14(%esp),%ebx
c0029bac:	53                   	push   %ebx
c0029bad:	e8 03 89 ff ff       	call   c00224b5 <lock_init>
  lock_acquire (&lock);
c0029bb2:	89 1c 24             	mov    %ebx,(%esp)
c0029bb5:	e8 7d 89 ff ff       	call   c0022537 <lock_acquire>
  thread_create ("acquire1", PRI_DEFAULT + 1, acquire1_thread_func, &lock);
c0029bba:	53                   	push   %ebx
c0029bbb:	68 53 9b 02 c0       	push   $0xc0029b53
c0029bc0:	6a 20                	push   $0x20
c0029bc2:	68 ed f0 02 c0       	push   $0xc002f0ed
c0029bc7:	e8 6e 6e ff ff       	call   c0020a3a <thread_create>
  msg ("This thread should have priority %d.  Actual priority: %d.",
c0029bcc:	83 c4 20             	add    $0x20,%esp
c0029bcf:	e8 52 71 ff ff       	call   c0020d26 <thread_get_priority>
c0029bd4:	83 ec 04             	sub    $0x4,%esp
c0029bd7:	50                   	push   %eax
c0029bd8:	6a 20                	push   $0x20
c0029bda:	68 54 f1 02 c0       	push   $0xc002f154
c0029bdf:	e8 04 f7 ff ff       	call   c00292e8 <msg>
  thread_create ("acquire2", PRI_DEFAULT + 2, acquire2_thread_func, &lock);
c0029be4:	53                   	push   %ebx
c0029be5:	68 20 9b 02 c0       	push   $0xc0029b20
c0029bea:	6a 21                	push   $0x21
c0029bec:	68 f6 f0 02 c0       	push   $0xc002f0f6
c0029bf1:	e8 44 6e ff ff       	call   c0020a3a <thread_create>
  msg ("This thread should have priority %d.  Actual priority: %d.",
c0029bf6:	83 c4 20             	add    $0x20,%esp
c0029bf9:	e8 28 71 ff ff       	call   c0020d26 <thread_get_priority>
c0029bfe:	83 ec 04             	sub    $0x4,%esp
c0029c01:	50                   	push   %eax
c0029c02:	6a 21                	push   $0x21
c0029c04:	68 54 f1 02 c0       	push   $0xc002f154
c0029c09:	e8 da f6 ff ff       	call   c00292e8 <msg>
  lock_release (&lock);
c0029c0e:	89 1c 24             	mov    %ebx,(%esp)
c0029c11:	e8 46 8a ff ff       	call   c002265c <lock_release>
  msg ("acquire2, acquire1 must already have finished, in that order.");
c0029c16:	c7 04 24 90 f1 02 c0 	movl   $0xc002f190,(%esp)
c0029c1d:	e8 c6 f6 ff ff       	call   c00292e8 <msg>
  msg ("This should be the last line before finishing this test.");
c0029c22:	c7 04 24 d0 f1 02 c0 	movl   $0xc002f1d0,(%esp)
c0029c29:	e8 ba f6 ff ff       	call   c00292e8 <msg>
}
c0029c2e:	83 c4 38             	add    $0x38,%esp
c0029c31:	5b                   	pop    %ebx
c0029c32:	c3                   	ret    
  ASSERT (!thread_mlfqs);
c0029c33:	83 ec 0c             	sub    $0xc,%esp
c0029c36:	68 98 ec 02 c0       	push   $0xc002ec98
c0029c3b:	68 9f cd 02 c0       	push   $0xc002cd9f
c0029c40:	68 9c cb 02 c0       	push   $0xc002cb9c
c0029c45:	6a 1b                	push   $0x1b
c0029c47:	68 00 f1 02 c0       	push   $0xc002f100
c0029c4c:	e8 be db ff ff       	call   c002780f <debug_panic>
  ASSERT (thread_get_priority () == PRI_DEFAULT);
c0029c51:	83 ec 0c             	sub    $0xc,%esp
c0029c54:	68 2c f1 02 c0       	push   $0xc002f12c
c0029c59:	68 9f cd 02 c0       	push   $0xc002cd9f
c0029c5e:	68 9c cb 02 c0       	push   $0xc002cb9c
c0029c63:	6a 1e                	push   $0x1e
c0029c65:	68 00 f1 02 c0       	push   $0xc002f100
c0029c6a:	e8 a0 db ff ff       	call   c002780f <debug_panic>

c0029c6f <b_thread_func>:
  msg ("Thread a finished.");
}

static void
b_thread_func (void *lock_) 
{
c0029c6f:	53                   	push   %ebx
c0029c70:	83 ec 14             	sub    $0x14,%esp
c0029c73:	8b 5c 24 1c          	mov    0x1c(%esp),%ebx
  struct lock *lock = lock_;

  lock_acquire (lock);
c0029c77:	53                   	push   %ebx
c0029c78:	e8 ba 88 ff ff       	call   c0022537 <lock_acquire>
  msg ("Thread b acquired lock b.");
c0029c7d:	c7 04 24 09 f2 02 c0 	movl   $0xc002f209,(%esp)
c0029c84:	e8 5f f6 ff ff       	call   c00292e8 <msg>
  lock_release (lock);
c0029c89:	89 1c 24             	mov    %ebx,(%esp)
c0029c8c:	e8 cb 89 ff ff       	call   c002265c <lock_release>
  msg ("Thread b finished.");
c0029c91:	c7 04 24 23 f2 02 c0 	movl   $0xc002f223,(%esp)
c0029c98:	e8 4b f6 ff ff       	call   c00292e8 <msg>
}
c0029c9d:	83 c4 18             	add    $0x18,%esp
c0029ca0:	5b                   	pop    %ebx
c0029ca1:	c3                   	ret    

c0029ca2 <a_thread_func>:
{
c0029ca2:	53                   	push   %ebx
c0029ca3:	83 ec 14             	sub    $0x14,%esp
c0029ca6:	8b 5c 24 1c          	mov    0x1c(%esp),%ebx
  lock_acquire (lock);
c0029caa:	53                   	push   %ebx
c0029cab:	e8 87 88 ff ff       	call   c0022537 <lock_acquire>
  msg ("Thread a acquired lock a.");
c0029cb0:	c7 04 24 36 f2 02 c0 	movl   $0xc002f236,(%esp)
c0029cb7:	e8 2c f6 ff ff       	call   c00292e8 <msg>
  lock_release (lock);
c0029cbc:	89 1c 24             	mov    %ebx,(%esp)
c0029cbf:	e8 98 89 ff ff       	call   c002265c <lock_release>
  msg ("Thread a finished.");
c0029cc4:	c7 04 24 50 f2 02 c0 	movl   $0xc002f250,(%esp)
c0029ccb:	e8 18 f6 ff ff       	call   c00292e8 <msg>
}
c0029cd0:	83 c4 18             	add    $0x18,%esp
c0029cd3:	5b                   	pop    %ebx
c0029cd4:	c3                   	ret    

c0029cd5 <test_priority_donate_multiple>:
{
c0029cd5:	56                   	push   %esi
c0029cd6:	53                   	push   %ebx
c0029cd7:	83 ec 34             	sub    $0x34,%esp
  ASSERT (!thread_mlfqs);
c0029cda:	80 3d ec 84 03 c0 00 	cmpb   $0x0,0xc00384ec
c0029ce1:	0f 85 e4 00 00 00    	jne    c0029dcb <test_priority_donate_multiple+0xf6>
  ASSERT (thread_get_priority () == PRI_DEFAULT);
c0029ce7:	e8 3a 70 ff ff       	call   c0020d26 <thread_get_priority>
c0029cec:	83 f8 1f             	cmp    $0x1f,%eax
c0029cef:	0f 85 f4 00 00 00    	jne    c0029de9 <test_priority_donate_multiple+0x114>
  lock_init (&a);
c0029cf5:	83 ec 0c             	sub    $0xc,%esp
c0029cf8:	8d 5c 24 24          	lea    0x24(%esp),%ebx
c0029cfc:	53                   	push   %ebx
c0029cfd:	e8 b3 87 ff ff       	call   c00224b5 <lock_init>
  lock_init (&b);
c0029d02:	83 c4 04             	add    $0x4,%esp
c0029d05:	8d 74 24 0c          	lea    0xc(%esp),%esi
c0029d09:	56                   	push   %esi
c0029d0a:	e8 a6 87 ff ff       	call   c00224b5 <lock_init>
  lock_acquire (&a);
c0029d0f:	89 1c 24             	mov    %ebx,(%esp)
c0029d12:	e8 20 88 ff ff       	call   c0022537 <lock_acquire>
  lock_acquire (&b);
c0029d17:	89 34 24             	mov    %esi,(%esp)
c0029d1a:	e8 18 88 ff ff       	call   c0022537 <lock_acquire>
  thread_create ("a", PRI_DEFAULT + 1, a_thread_func, &a);
c0029d1f:	53                   	push   %ebx
c0029d20:	68 a2 9c 02 c0       	push   $0xc0029ca2
c0029d25:	6a 20                	push   $0x20
c0029d27:	68 8b de 02 c0       	push   $0xc002de8b
c0029d2c:	e8 09 6d ff ff       	call   c0020a3a <thread_create>
  msg ("Main thread should have priority %d.  Actual priority: %d.",
c0029d31:	83 c4 20             	add    $0x20,%esp
c0029d34:	e8 ed 6f ff ff       	call   c0020d26 <thread_get_priority>
c0029d39:	83 ec 04             	sub    $0x4,%esp
c0029d3c:	50                   	push   %eax
c0029d3d:	6a 20                	push   $0x20
c0029d3f:	68 94 f2 02 c0       	push   $0xc002f294
c0029d44:	e8 9f f5 ff ff       	call   c00292e8 <msg>
  thread_create ("b", PRI_DEFAULT + 2, b_thread_func, &b);
c0029d49:	56                   	push   %esi
c0029d4a:	68 6f 9c 02 c0       	push   $0xc0029c6f
c0029d4f:	6a 21                	push   $0x21
c0029d51:	68 d7 e7 02 c0       	push   $0xc002e7d7
c0029d56:	e8 df 6c ff ff       	call   c0020a3a <thread_create>
  msg ("Main thread should have priority %d.  Actual priority: %d.",
c0029d5b:	83 c4 20             	add    $0x20,%esp
c0029d5e:	e8 c3 6f ff ff       	call   c0020d26 <thread_get_priority>
c0029d63:	83 ec 04             	sub    $0x4,%esp
c0029d66:	50                   	push   %eax
c0029d67:	6a 21                	push   $0x21
c0029d69:	68 94 f2 02 c0       	push   $0xc002f294
c0029d6e:	e8 75 f5 ff ff       	call   c00292e8 <msg>
  lock_release (&b);
c0029d73:	89 34 24             	mov    %esi,(%esp)
c0029d76:	e8 e1 88 ff ff       	call   c002265c <lock_release>
  msg ("Thread b should have just finished.");
c0029d7b:	c7 04 24 d0 f2 02 c0 	movl   $0xc002f2d0,(%esp)
c0029d82:	e8 61 f5 ff ff       	call   c00292e8 <msg>
  msg ("Main thread should have priority %d.  Actual priority: %d.",
c0029d87:	e8 9a 6f ff ff       	call   c0020d26 <thread_get_priority>
c0029d8c:	83 c4 0c             	add    $0xc,%esp
c0029d8f:	50                   	push   %eax
c0029d90:	6a 20                	push   $0x20
c0029d92:	68 94 f2 02 c0       	push   $0xc002f294
c0029d97:	e8 4c f5 ff ff       	call   c00292e8 <msg>
  lock_release (&a);
c0029d9c:	89 1c 24             	mov    %ebx,(%esp)
c0029d9f:	e8 b8 88 ff ff       	call   c002265c <lock_release>
  msg ("Thread a should have just finished.");
c0029da4:	c7 04 24 f4 f2 02 c0 	movl   $0xc002f2f4,(%esp)
c0029dab:	e8 38 f5 ff ff       	call   c00292e8 <msg>
  msg ("Main thread should have priority %d.  Actual priority: %d.",
c0029db0:	e8 71 6f ff ff       	call   c0020d26 <thread_get_priority>
c0029db5:	83 c4 0c             	add    $0xc,%esp
c0029db8:	50                   	push   %eax
c0029db9:	6a 1f                	push   $0x1f
c0029dbb:	68 94 f2 02 c0       	push   $0xc002f294
c0029dc0:	e8 23 f5 ff ff       	call   c00292e8 <msg>
}
c0029dc5:	83 c4 44             	add    $0x44,%esp
c0029dc8:	5b                   	pop    %ebx
c0029dc9:	5e                   	pop    %esi
c0029dca:	c3                   	ret    
  ASSERT (!thread_mlfqs);
c0029dcb:	83 ec 0c             	sub    $0xc,%esp
c0029dce:	68 98 ec 02 c0       	push   $0xc002ec98
c0029dd3:	68 9f cd 02 c0       	push   $0xc002cd9f
c0029dd8:	68 b8 cb 02 c0       	push   $0xc002cbb8
c0029ddd:	6a 1b                	push   $0x1b
c0029ddf:	68 64 f2 02 c0       	push   $0xc002f264
c0029de4:	e8 26 da ff ff       	call   c002780f <debug_panic>
  ASSERT (thread_get_priority () == PRI_DEFAULT);
c0029de9:	83 ec 0c             	sub    $0xc,%esp
c0029dec:	68 2c f1 02 c0       	push   $0xc002f12c
c0029df1:	68 9f cd 02 c0       	push   $0xc002cd9f
c0029df6:	68 b8 cb 02 c0       	push   $0xc002cbb8
c0029dfb:	6a 1e                	push   $0x1e
c0029dfd:	68 64 f2 02 c0       	push   $0xc002f264
c0029e02:	e8 08 da ff ff       	call   c002780f <debug_panic>

c0029e07 <c_thread_func>:
  msg ("Thread b finished.");
}

static void
c_thread_func (void *a_ UNUSED) 
{
c0029e07:	83 ec 18             	sub    $0x18,%esp
  msg ("Thread c finished.");
c0029e0a:	68 18 f3 02 c0       	push   $0xc002f318
c0029e0f:	e8 d4 f4 ff ff       	call   c00292e8 <msg>
}
c0029e14:	83 c4 1c             	add    $0x1c,%esp
c0029e17:	c3                   	ret    

c0029e18 <b_thread_func>:
{
c0029e18:	53                   	push   %ebx
c0029e19:	83 ec 14             	sub    $0x14,%esp
c0029e1c:	8b 5c 24 1c          	mov    0x1c(%esp),%ebx
  lock_acquire (lock);
c0029e20:	53                   	push   %ebx
c0029e21:	e8 11 87 ff ff       	call   c0022537 <lock_acquire>
  msg ("Thread b acquired lock b.");
c0029e26:	c7 04 24 09 f2 02 c0 	movl   $0xc002f209,(%esp)
c0029e2d:	e8 b6 f4 ff ff       	call   c00292e8 <msg>
  lock_release (lock);
c0029e32:	89 1c 24             	mov    %ebx,(%esp)
c0029e35:	e8 22 88 ff ff       	call   c002265c <lock_release>
  msg ("Thread b finished.");
c0029e3a:	c7 04 24 23 f2 02 c0 	movl   $0xc002f223,(%esp)
c0029e41:	e8 a2 f4 ff ff       	call   c00292e8 <msg>
}
c0029e46:	83 c4 18             	add    $0x18,%esp
c0029e49:	5b                   	pop    %ebx
c0029e4a:	c3                   	ret    

c0029e4b <a_thread_func>:
{
c0029e4b:	53                   	push   %ebx
c0029e4c:	83 ec 14             	sub    $0x14,%esp
c0029e4f:	8b 5c 24 1c          	mov    0x1c(%esp),%ebx
  lock_acquire (lock);
c0029e53:	53                   	push   %ebx
c0029e54:	e8 de 86 ff ff       	call   c0022537 <lock_acquire>
  msg ("Thread a acquired lock a.");
c0029e59:	c7 04 24 36 f2 02 c0 	movl   $0xc002f236,(%esp)
c0029e60:	e8 83 f4 ff ff       	call   c00292e8 <msg>
  lock_release (lock);
c0029e65:	89 1c 24             	mov    %ebx,(%esp)
c0029e68:	e8 ef 87 ff ff       	call   c002265c <lock_release>
  msg ("Thread a finished.");
c0029e6d:	c7 04 24 50 f2 02 c0 	movl   $0xc002f250,(%esp)
c0029e74:	e8 6f f4 ff ff       	call   c00292e8 <msg>
}
c0029e79:	83 c4 18             	add    $0x18,%esp
c0029e7c:	5b                   	pop    %ebx
c0029e7d:	c3                   	ret    

c0029e7e <test_priority_donate_multiple2>:
{
c0029e7e:	56                   	push   %esi
c0029e7f:	53                   	push   %ebx
c0029e80:	83 ec 34             	sub    $0x34,%esp
  ASSERT (!thread_mlfqs);
c0029e83:	80 3d ec 84 03 c0 00 	cmpb   $0x0,0xc00384ec
c0029e8a:	0f 85 eb 00 00 00    	jne    c0029f7b <test_priority_donate_multiple2+0xfd>
  ASSERT (thread_get_priority () == PRI_DEFAULT);
c0029e90:	e8 91 6e ff ff       	call   c0020d26 <thread_get_priority>
c0029e95:	83 f8 1f             	cmp    $0x1f,%eax
c0029e98:	0f 85 fb 00 00 00    	jne    c0029f99 <test_priority_donate_multiple2+0x11b>
  lock_init (&a);
c0029e9e:	83 ec 0c             	sub    $0xc,%esp
c0029ea1:	8d 74 24 24          	lea    0x24(%esp),%esi
c0029ea5:	56                   	push   %esi
c0029ea6:	e8 0a 86 ff ff       	call   c00224b5 <lock_init>
  lock_init (&b);
c0029eab:	83 c4 04             	add    $0x4,%esp
c0029eae:	8d 5c 24 0c          	lea    0xc(%esp),%ebx
c0029eb2:	53                   	push   %ebx
c0029eb3:	e8 fd 85 ff ff       	call   c00224b5 <lock_init>
  lock_acquire (&a);
c0029eb8:	89 34 24             	mov    %esi,(%esp)
c0029ebb:	e8 77 86 ff ff       	call   c0022537 <lock_acquire>
  lock_acquire (&b);
c0029ec0:	89 1c 24             	mov    %ebx,(%esp)
c0029ec3:	e8 6f 86 ff ff       	call   c0022537 <lock_acquire>
  thread_create ("a", PRI_DEFAULT + 3, a_thread_func, &a);
c0029ec8:	56                   	push   %esi
c0029ec9:	68 4b 9e 02 c0       	push   $0xc0029e4b
c0029ece:	6a 22                	push   $0x22
c0029ed0:	68 8b de 02 c0       	push   $0xc002de8b
c0029ed5:	e8 60 6b ff ff       	call   c0020a3a <thread_create>
  msg ("Main thread should have priority %d.  Actual priority: %d.",
c0029eda:	83 c4 20             	add    $0x20,%esp
c0029edd:	e8 44 6e ff ff       	call   c0020d26 <thread_get_priority>
c0029ee2:	83 ec 04             	sub    $0x4,%esp
c0029ee5:	50                   	push   %eax
c0029ee6:	6a 22                	push   $0x22
c0029ee8:	68 94 f2 02 c0       	push   $0xc002f294
c0029eed:	e8 f6 f3 ff ff       	call   c00292e8 <msg>
  thread_create ("c", PRI_DEFAULT + 1, c_thread_func, NULL);
c0029ef2:	6a 00                	push   $0x0
c0029ef4:	68 07 9e 02 c0       	push   $0xc0029e07
c0029ef9:	6a 20                	push   $0x20
c0029efb:	68 76 e2 02 c0       	push   $0xc002e276
c0029f00:	e8 35 6b ff ff       	call   c0020a3a <thread_create>
  thread_create ("b", PRI_DEFAULT + 5, b_thread_func, &b);
c0029f05:	83 c4 20             	add    $0x20,%esp
c0029f08:	53                   	push   %ebx
c0029f09:	68 18 9e 02 c0       	push   $0xc0029e18
c0029f0e:	6a 24                	push   $0x24
c0029f10:	68 d7 e7 02 c0       	push   $0xc002e7d7
c0029f15:	e8 20 6b ff ff       	call   c0020a3a <thread_create>
  msg ("Main thread should have priority %d.  Actual priority: %d.",
c0029f1a:	e8 07 6e ff ff       	call   c0020d26 <thread_get_priority>
c0029f1f:	83 c4 0c             	add    $0xc,%esp
c0029f22:	50                   	push   %eax
c0029f23:	6a 24                	push   $0x24
c0029f25:	68 94 f2 02 c0       	push   $0xc002f294
c0029f2a:	e8 b9 f3 ff ff       	call   c00292e8 <msg>
  lock_release (&a);
c0029f2f:	89 34 24             	mov    %esi,(%esp)
c0029f32:	e8 25 87 ff ff       	call   c002265c <lock_release>
  msg ("Main thread should have priority %d.  Actual priority: %d.",
c0029f37:	e8 ea 6d ff ff       	call   c0020d26 <thread_get_priority>
c0029f3c:	83 c4 0c             	add    $0xc,%esp
c0029f3f:	50                   	push   %eax
c0029f40:	6a 24                	push   $0x24
c0029f42:	68 94 f2 02 c0       	push   $0xc002f294
c0029f47:	e8 9c f3 ff ff       	call   c00292e8 <msg>
  lock_release (&b);
c0029f4c:	89 1c 24             	mov    %ebx,(%esp)
c0029f4f:	e8 08 87 ff ff       	call   c002265c <lock_release>
  msg ("Threads b, a, c should have just finished, in that order.");
c0029f54:	c7 04 24 5c f3 02 c0 	movl   $0xc002f35c,(%esp)
c0029f5b:	e8 88 f3 ff ff       	call   c00292e8 <msg>
  msg ("Main thread should have priority %d.  Actual priority: %d.",
c0029f60:	e8 c1 6d ff ff       	call   c0020d26 <thread_get_priority>
c0029f65:	83 c4 0c             	add    $0xc,%esp
c0029f68:	50                   	push   %eax
c0029f69:	6a 1f                	push   $0x1f
c0029f6b:	68 94 f2 02 c0       	push   $0xc002f294
c0029f70:	e8 73 f3 ff ff       	call   c00292e8 <msg>
}
c0029f75:	83 c4 44             	add    $0x44,%esp
c0029f78:	5b                   	pop    %ebx
c0029f79:	5e                   	pop    %esi
c0029f7a:	c3                   	ret    
  ASSERT (!thread_mlfqs);
c0029f7b:	83 ec 0c             	sub    $0xc,%esp
c0029f7e:	68 98 ec 02 c0       	push   $0xc002ec98
c0029f83:	68 9f cd 02 c0       	push   $0xc002cd9f
c0029f88:	68 d8 cb 02 c0       	push   $0xc002cbd8
c0029f8d:	6a 21                	push   $0x21
c0029f8f:	68 2c f3 02 c0       	push   $0xc002f32c
c0029f94:	e8 76 d8 ff ff       	call   c002780f <debug_panic>
  ASSERT (thread_get_priority () == PRI_DEFAULT);
c0029f99:	83 ec 0c             	sub    $0xc,%esp
c0029f9c:	68 2c f1 02 c0       	push   $0xc002f12c
c0029fa1:	68 9f cd 02 c0       	push   $0xc002cd9f
c0029fa6:	68 d8 cb 02 c0       	push   $0xc002cbd8
c0029fab:	6a 24                	push   $0x24
c0029fad:	68 2c f3 02 c0       	push   $0xc002f32c
c0029fb2:	e8 58 d8 ff ff       	call   c002780f <debug_panic>

c0029fb7 <high_thread_func>:
  msg ("Middle thread finished.");
}

static void
high_thread_func (void *lock_) 
{
c0029fb7:	53                   	push   %ebx
c0029fb8:	83 ec 14             	sub    $0x14,%esp
c0029fbb:	8b 5c 24 1c          	mov    0x1c(%esp),%ebx
  struct lock *lock = lock_;

  lock_acquire (lock);
c0029fbf:	53                   	push   %ebx
c0029fc0:	e8 72 85 ff ff       	call   c0022537 <lock_acquire>
  msg ("High thread got the lock.");
c0029fc5:	c7 04 24 96 f3 02 c0 	movl   $0xc002f396,(%esp)
c0029fcc:	e8 17 f3 ff ff       	call   c00292e8 <msg>
  lock_release (lock);
c0029fd1:	89 1c 24             	mov    %ebx,(%esp)
c0029fd4:	e8 83 86 ff ff       	call   c002265c <lock_release>
  msg ("High thread finished.");
c0029fd9:	c7 04 24 b0 f3 02 c0 	movl   $0xc002f3b0,(%esp)
c0029fe0:	e8 03 f3 ff ff       	call   c00292e8 <msg>
}
c0029fe5:	83 c4 18             	add    $0x18,%esp
c0029fe8:	5b                   	pop    %ebx
c0029fe9:	c3                   	ret    

c0029fea <medium_thread_func>:
{
c0029fea:	53                   	push   %ebx
c0029feb:	83 ec 14             	sub    $0x14,%esp
c0029fee:	8b 5c 24 1c          	mov    0x1c(%esp),%ebx
  lock_acquire (locks->b);
c0029ff2:	ff 73 04             	pushl  0x4(%ebx)
c0029ff5:	e8 3d 85 ff ff       	call   c0022537 <lock_acquire>
  lock_acquire (locks->a);
c0029ffa:	83 c4 04             	add    $0x4,%esp
c0029ffd:	ff 33                	pushl  (%ebx)
c0029fff:	e8 33 85 ff ff       	call   c0022537 <lock_acquire>
  msg ("Medium thread should have priority %d.  Actual priority: %d.",
c002a004:	e8 1d 6d ff ff       	call   c0020d26 <thread_get_priority>
c002a009:	83 c4 0c             	add    $0xc,%esp
c002a00c:	50                   	push   %eax
c002a00d:	6a 21                	push   $0x21
c002a00f:	68 08 f4 02 c0       	push   $0xc002f408
c002a014:	e8 cf f2 ff ff       	call   c00292e8 <msg>
  msg ("Medium thread got the lock.");
c002a019:	c7 04 24 c6 f3 02 c0 	movl   $0xc002f3c6,(%esp)
c002a020:	e8 c3 f2 ff ff       	call   c00292e8 <msg>
  lock_release (locks->a);
c002a025:	83 c4 04             	add    $0x4,%esp
c002a028:	ff 33                	pushl  (%ebx)
c002a02a:	e8 2d 86 ff ff       	call   c002265c <lock_release>
  thread_yield ();
c002a02f:	e8 d0 6f ff ff       	call   c0021004 <thread_yield>
  lock_release (locks->b);
c002a034:	83 c4 04             	add    $0x4,%esp
c002a037:	ff 73 04             	pushl  0x4(%ebx)
c002a03a:	e8 1d 86 ff ff       	call   c002265c <lock_release>
  thread_yield ();
c002a03f:	e8 c0 6f ff ff       	call   c0021004 <thread_yield>
  msg ("High thread should have just finished.");
c002a044:	c7 04 24 48 f4 02 c0 	movl   $0xc002f448,(%esp)
c002a04b:	e8 98 f2 ff ff       	call   c00292e8 <msg>
  msg ("Middle thread finished.");
c002a050:	c7 04 24 e2 f3 02 c0 	movl   $0xc002f3e2,(%esp)
c002a057:	e8 8c f2 ff ff       	call   c00292e8 <msg>
}
c002a05c:	83 c4 18             	add    $0x18,%esp
c002a05f:	5b                   	pop    %ebx
c002a060:	c3                   	ret    

c002a061 <test_priority_donate_nest>:
{
c002a061:	56                   	push   %esi
c002a062:	53                   	push   %ebx
c002a063:	83 ec 44             	sub    $0x44,%esp
  ASSERT (!thread_mlfqs);
c002a066:	80 3d ec 84 03 c0 00 	cmpb   $0x0,0xc00384ec
c002a06d:	0f 85 ce 00 00 00    	jne    c002a141 <test_priority_donate_nest+0xe0>
  ASSERT (thread_get_priority () == PRI_DEFAULT);
c002a073:	e8 ae 6c ff ff       	call   c0020d26 <thread_get_priority>
c002a078:	83 f8 1f             	cmp    $0x1f,%eax
c002a07b:	0f 85 de 00 00 00    	jne    c002a15f <test_priority_donate_nest+0xfe>
  lock_init (&a);
c002a081:	83 ec 0c             	sub    $0xc,%esp
c002a084:	8d 5c 24 34          	lea    0x34(%esp),%ebx
c002a088:	53                   	push   %ebx
c002a089:	e8 27 84 ff ff       	call   c00224b5 <lock_init>
  lock_init (&b);
c002a08e:	83 c4 04             	add    $0x4,%esp
c002a091:	8d 74 24 1c          	lea    0x1c(%esp),%esi
c002a095:	56                   	push   %esi
c002a096:	e8 1a 84 ff ff       	call   c00224b5 <lock_init>
  lock_acquire (&a);
c002a09b:	89 1c 24             	mov    %ebx,(%esp)
c002a09e:	e8 94 84 ff ff       	call   c0022537 <lock_acquire>
  locks.a = &a;
c002a0a3:	89 5c 24 18          	mov    %ebx,0x18(%esp)
  locks.b = &b;
c002a0a7:	89 74 24 1c          	mov    %esi,0x1c(%esp)
  thread_create ("medium", PRI_DEFAULT + 1, medium_thread_func, &locks);
c002a0ab:	8d 44 24 18          	lea    0x18(%esp),%eax
c002a0af:	50                   	push   %eax
c002a0b0:	68 ea 9f 02 c0       	push   $0xc0029fea
c002a0b5:	6a 20                	push   $0x20
c002a0b7:	68 fa f3 02 c0       	push   $0xc002f3fa
c002a0bc:	e8 79 69 ff ff       	call   c0020a3a <thread_create>
  thread_yield ();
c002a0c1:	83 c4 20             	add    $0x20,%esp
c002a0c4:	e8 3b 6f ff ff       	call   c0021004 <thread_yield>
  msg ("Low thread should have priority %d.  Actual priority: %d.",
c002a0c9:	e8 58 6c ff ff       	call   c0020d26 <thread_get_priority>
c002a0ce:	83 ec 04             	sub    $0x4,%esp
c002a0d1:	50                   	push   %eax
c002a0d2:	6a 20                	push   $0x20
c002a0d4:	68 9c f4 02 c0       	push   $0xc002f49c
c002a0d9:	e8 0a f2 ff ff       	call   c00292e8 <msg>
  thread_create ("high", PRI_DEFAULT + 2, high_thread_func, &b);
c002a0de:	56                   	push   %esi
c002a0df:	68 b7 9f 02 c0       	push   $0xc0029fb7
c002a0e4:	6a 21                	push   $0x21
c002a0e6:	68 01 f4 02 c0       	push   $0xc002f401
c002a0eb:	e8 4a 69 ff ff       	call   c0020a3a <thread_create>
  thread_yield ();
c002a0f0:	83 c4 20             	add    $0x20,%esp
c002a0f3:	e8 0c 6f ff ff       	call   c0021004 <thread_yield>
  msg ("Low thread should have priority %d.  Actual priority: %d.",
c002a0f8:	e8 29 6c ff ff       	call   c0020d26 <thread_get_priority>
c002a0fd:	83 ec 04             	sub    $0x4,%esp
c002a100:	50                   	push   %eax
c002a101:	6a 21                	push   $0x21
c002a103:	68 9c f4 02 c0       	push   $0xc002f49c
c002a108:	e8 db f1 ff ff       	call   c00292e8 <msg>
  lock_release (&a);
c002a10d:	89 1c 24             	mov    %ebx,(%esp)
c002a110:	e8 47 85 ff ff       	call   c002265c <lock_release>
  thread_yield ();
c002a115:	e8 ea 6e ff ff       	call   c0021004 <thread_yield>
  msg ("Medium thread should just have finished.");
c002a11a:	c7 04 24 d8 f4 02 c0 	movl   $0xc002f4d8,(%esp)
c002a121:	e8 c2 f1 ff ff       	call   c00292e8 <msg>
  msg ("Low thread should have priority %d.  Actual priority: %d.",
c002a126:	e8 fb 6b ff ff       	call   c0020d26 <thread_get_priority>
c002a12b:	83 c4 0c             	add    $0xc,%esp
c002a12e:	50                   	push   %eax
c002a12f:	6a 1f                	push   $0x1f
c002a131:	68 9c f4 02 c0       	push   $0xc002f49c
c002a136:	e8 ad f1 ff ff       	call   c00292e8 <msg>
}
c002a13b:	83 c4 54             	add    $0x54,%esp
c002a13e:	5b                   	pop    %ebx
c002a13f:	5e                   	pop    %esi
c002a140:	c3                   	ret    
  ASSERT (!thread_mlfqs);
c002a141:	83 ec 0c             	sub    $0xc,%esp
c002a144:	68 98 ec 02 c0       	push   $0xc002ec98
c002a149:	68 9f cd 02 c0       	push   $0xc002cd9f
c002a14e:	68 f8 cb 02 c0       	push   $0xc002cbf8
c002a153:	6a 22                	push   $0x22
c002a155:	68 70 f4 02 c0       	push   $0xc002f470
c002a15a:	e8 b0 d6 ff ff       	call   c002780f <debug_panic>
  ASSERT (thread_get_priority () == PRI_DEFAULT);
c002a15f:	83 ec 0c             	sub    $0xc,%esp
c002a162:	68 2c f1 02 c0       	push   $0xc002f12c
c002a167:	68 9f cd 02 c0       	push   $0xc002cd9f
c002a16c:	68 f8 cb 02 c0       	push   $0xc002cbf8
c002a171:	6a 25                	push   $0x25
c002a173:	68 70 f4 02 c0       	push   $0xc002f470
c002a178:	e8 92 d6 ff ff       	call   c002780f <debug_panic>

c002a17d <h_thread_func>:
  msg ("Thread M finished.");
}

static void
h_thread_func (void *ls_) 
{
c002a17d:	53                   	push   %ebx
c002a17e:	83 ec 14             	sub    $0x14,%esp
c002a181:	8b 5c 24 1c          	mov    0x1c(%esp),%ebx
  struct lock_and_sema *ls = ls_;

  lock_acquire (&ls->lock);
c002a185:	53                   	push   %ebx
c002a186:	e8 ac 83 ff ff       	call   c0022537 <lock_acquire>
  msg ("Thread H acquired lock.");
c002a18b:	c7 04 24 01 f5 02 c0 	movl   $0xc002f501,(%esp)
c002a192:	e8 51 f1 ff ff       	call   c00292e8 <msg>

  sema_up (&ls->sema);
c002a197:	8d 43 18             	lea    0x18(%ebx),%eax
c002a19a:	89 04 24             	mov    %eax,(%esp)
c002a19d:	e8 00 82 ff ff       	call   c00223a2 <sema_up>
  lock_release (&ls->lock);
c002a1a2:	89 1c 24             	mov    %ebx,(%esp)
c002a1a5:	e8 b2 84 ff ff       	call   c002265c <lock_release>
  msg ("Thread H finished.");
c002a1aa:	c7 04 24 19 f5 02 c0 	movl   $0xc002f519,(%esp)
c002a1b1:	e8 32 f1 ff ff       	call   c00292e8 <msg>
}
c002a1b6:	83 c4 18             	add    $0x18,%esp
c002a1b9:	5b                   	pop    %ebx
c002a1ba:	c3                   	ret    

c002a1bb <m_thread_func>:
{
c002a1bb:	83 ec 18             	sub    $0x18,%esp
  sema_down (&ls->sema);
c002a1be:	8b 44 24 1c          	mov    0x1c(%esp),%eax
c002a1c2:	83 c0 18             	add    $0x18,%eax
c002a1c5:	50                   	push   %eax
c002a1c6:	e8 f6 80 ff ff       	call   c00222c1 <sema_down>
  msg ("Thread M finished.");
c002a1cb:	c7 04 24 2c f5 02 c0 	movl   $0xc002f52c,(%esp)
c002a1d2:	e8 11 f1 ff ff       	call   c00292e8 <msg>
}
c002a1d7:	83 c4 1c             	add    $0x1c,%esp
c002a1da:	c3                   	ret    

c002a1db <l_thread_func>:
{
c002a1db:	53                   	push   %ebx
c002a1dc:	83 ec 14             	sub    $0x14,%esp
c002a1df:	8b 5c 24 1c          	mov    0x1c(%esp),%ebx
  lock_acquire (&ls->lock);
c002a1e3:	53                   	push   %ebx
c002a1e4:	e8 4e 83 ff ff       	call   c0022537 <lock_acquire>
  msg ("Thread L acquired lock.");
c002a1e9:	c7 04 24 3f f5 02 c0 	movl   $0xc002f53f,(%esp)
c002a1f0:	e8 f3 f0 ff ff       	call   c00292e8 <msg>
  sema_down (&ls->sema);
c002a1f5:	8d 43 18             	lea    0x18(%ebx),%eax
c002a1f8:	89 04 24             	mov    %eax,(%esp)
c002a1fb:	e8 c1 80 ff ff       	call   c00222c1 <sema_down>
  msg ("Thread L downed semaphore.");
c002a200:	c7 04 24 57 f5 02 c0 	movl   $0xc002f557,(%esp)
c002a207:	e8 dc f0 ff ff       	call   c00292e8 <msg>
  lock_release (&ls->lock);
c002a20c:	89 1c 24             	mov    %ebx,(%esp)
c002a20f:	e8 48 84 ff ff       	call   c002265c <lock_release>
  msg ("Thread L finished.");
c002a214:	c7 04 24 72 f5 02 c0 	movl   $0xc002f572,(%esp)
c002a21b:	e8 c8 f0 ff ff       	call   c00292e8 <msg>
}
c002a220:	83 c4 18             	add    $0x18,%esp
c002a223:	5b                   	pop    %ebx
c002a224:	c3                   	ret    

c002a225 <test_priority_donate_sema>:
{
c002a225:	56                   	push   %esi
c002a226:	53                   	push   %ebx
c002a227:	83 ec 34             	sub    $0x34,%esp
  ASSERT (!thread_mlfqs);
c002a22a:	80 3d ec 84 03 c0 00 	cmpb   $0x0,0xc00384ec
c002a231:	75 7e                	jne    c002a2b1 <test_priority_donate_sema+0x8c>
  ASSERT (thread_get_priority () == PRI_DEFAULT);
c002a233:	e8 ee 6a ff ff       	call   c0020d26 <thread_get_priority>
c002a238:	83 f8 1f             	cmp    $0x1f,%eax
c002a23b:	0f 85 8e 00 00 00    	jne    c002a2cf <test_priority_donate_sema+0xaa>
  lock_init (&ls.lock);
c002a241:	83 ec 0c             	sub    $0xc,%esp
c002a244:	8d 5c 24 10          	lea    0x10(%esp),%ebx
c002a248:	53                   	push   %ebx
c002a249:	e8 67 82 ff ff       	call   c00224b5 <lock_init>
  sema_init (&ls.sema, 0);
c002a24e:	83 c4 08             	add    $0x8,%esp
c002a251:	6a 00                	push   $0x0
c002a253:	8d 74 24 28          	lea    0x28(%esp),%esi
c002a257:	56                   	push   %esi
c002a258:	e8 25 80 ff ff       	call   c0022282 <sema_init>
  thread_create ("low", PRI_DEFAULT + 1, l_thread_func, &ls);
c002a25d:	53                   	push   %ebx
c002a25e:	68 db a1 02 c0       	push   $0xc002a1db
c002a263:	6a 20                	push   $0x20
c002a265:	68 85 f5 02 c0       	push   $0xc002f585
c002a26a:	e8 cb 67 ff ff       	call   c0020a3a <thread_create>
  thread_create ("med", PRI_DEFAULT + 3, m_thread_func, &ls);
c002a26f:	83 c4 20             	add    $0x20,%esp
c002a272:	53                   	push   %ebx
c002a273:	68 bb a1 02 c0       	push   $0xc002a1bb
c002a278:	6a 22                	push   $0x22
c002a27a:	68 89 f5 02 c0       	push   $0xc002f589
c002a27f:	e8 b6 67 ff ff       	call   c0020a3a <thread_create>
  thread_create ("high", PRI_DEFAULT + 5, h_thread_func, &ls);
c002a284:	53                   	push   %ebx
c002a285:	68 7d a1 02 c0       	push   $0xc002a17d
c002a28a:	6a 24                	push   $0x24
c002a28c:	68 01 f4 02 c0       	push   $0xc002f401
c002a291:	e8 a4 67 ff ff       	call   c0020a3a <thread_create>
  sema_up (&ls.sema);
c002a296:	83 c4 14             	add    $0x14,%esp
c002a299:	56                   	push   %esi
c002a29a:	e8 03 81 ff ff       	call   c00223a2 <sema_up>
  msg ("Main thread finished.");
c002a29f:	c7 04 24 8d f5 02 c0 	movl   $0xc002f58d,(%esp)
c002a2a6:	e8 3d f0 ff ff       	call   c00292e8 <msg>
}
c002a2ab:	83 c4 44             	add    $0x44,%esp
c002a2ae:	5b                   	pop    %ebx
c002a2af:	5e                   	pop    %esi
c002a2b0:	c3                   	ret    
  ASSERT (!thread_mlfqs);
c002a2b1:	83 ec 0c             	sub    $0xc,%esp
c002a2b4:	68 98 ec 02 c0       	push   $0xc002ec98
c002a2b9:	68 9f cd 02 c0       	push   $0xc002cd9f
c002a2be:	68 14 cc 02 c0       	push   $0xc002cc14
c002a2c3:	6a 23                	push   $0x23
c002a2c5:	68 a4 f5 02 c0       	push   $0xc002f5a4
c002a2ca:	e8 40 d5 ff ff       	call   c002780f <debug_panic>
  ASSERT (thread_get_priority () == PRI_DEFAULT);
c002a2cf:	83 ec 0c             	sub    $0xc,%esp
c002a2d2:	68 2c f1 02 c0       	push   $0xc002f12c
c002a2d7:	68 9f cd 02 c0       	push   $0xc002cd9f
c002a2dc:	68 14 cc 02 c0       	push   $0xc002cc14
c002a2e1:	6a 26                	push   $0x26
c002a2e3:	68 a4 f5 02 c0       	push   $0xc002f5a4
c002a2e8:	e8 22 d5 ff ff       	call   c002780f <debug_panic>

c002a2ed <acquire_thread_func>:
       PRI_DEFAULT - 10, thread_get_priority ());
}

static void
acquire_thread_func (void *lock_) 
{
c002a2ed:	53                   	push   %ebx
c002a2ee:	83 ec 14             	sub    $0x14,%esp
c002a2f1:	8b 5c 24 1c          	mov    0x1c(%esp),%ebx
  struct lock *lock = lock_;

  lock_acquire (lock);
c002a2f5:	53                   	push   %ebx
c002a2f6:	e8 3c 82 ff ff       	call   c0022537 <lock_acquire>
  msg ("acquire: got the lock");
c002a2fb:	c7 04 24 cf f5 02 c0 	movl   $0xc002f5cf,(%esp)
c002a302:	e8 e1 ef ff ff       	call   c00292e8 <msg>
  lock_release (lock);
c002a307:	89 1c 24             	mov    %ebx,(%esp)
c002a30a:	e8 4d 83 ff ff       	call   c002265c <lock_release>
  msg ("acquire: done");
c002a30f:	c7 04 24 e5 f5 02 c0 	movl   $0xc002f5e5,(%esp)
c002a316:	e8 cd ef ff ff       	call   c00292e8 <msg>
}
c002a31b:	83 c4 18             	add    $0x18,%esp
c002a31e:	5b                   	pop    %ebx
c002a31f:	c3                   	ret    

c002a320 <test_priority_donate_lower>:
{
c002a320:	53                   	push   %ebx
c002a321:	83 ec 28             	sub    $0x28,%esp
  ASSERT (!thread_mlfqs);
c002a324:	80 3d ec 84 03 c0 00 	cmpb   $0x0,0xc00384ec
c002a32b:	0f 85 a8 00 00 00    	jne    c002a3d9 <test_priority_donate_lower+0xb9>
  ASSERT (thread_get_priority () == PRI_DEFAULT);
c002a331:	e8 f0 69 ff ff       	call   c0020d26 <thread_get_priority>
c002a336:	83 f8 1f             	cmp    $0x1f,%eax
c002a339:	0f 85 b8 00 00 00    	jne    c002a3f7 <test_priority_donate_lower+0xd7>
  lock_init (&lock);
c002a33f:	83 ec 0c             	sub    $0xc,%esp
c002a342:	8d 5c 24 14          	lea    0x14(%esp),%ebx
c002a346:	53                   	push   %ebx
c002a347:	e8 69 81 ff ff       	call   c00224b5 <lock_init>
  lock_acquire (&lock);
c002a34c:	89 1c 24             	mov    %ebx,(%esp)
c002a34f:	e8 e3 81 ff ff       	call   c0022537 <lock_acquire>
  thread_create ("acquire", PRI_DEFAULT + 10, acquire_thread_func, &lock);
c002a354:	53                   	push   %ebx
c002a355:	68 ed a2 02 c0       	push   $0xc002a2ed
c002a35a:	6a 29                	push   $0x29
c002a35c:	68 f3 f5 02 c0       	push   $0xc002f5f3
c002a361:	e8 d4 66 ff ff       	call   c0020a3a <thread_create>
  msg ("Main thread should have priority %d.  Actual priority: %d.",
c002a366:	83 c4 20             	add    $0x20,%esp
c002a369:	e8 b8 69 ff ff       	call   c0020d26 <thread_get_priority>
c002a36e:	83 ec 04             	sub    $0x4,%esp
c002a371:	50                   	push   %eax
c002a372:	6a 29                	push   $0x29
c002a374:	68 94 f2 02 c0       	push   $0xc002f294
c002a379:	e8 6a ef ff ff       	call   c00292e8 <msg>
  msg ("Lowering base priority...");
c002a37e:	c7 04 24 fb f5 02 c0 	movl   $0xc002f5fb,(%esp)
c002a385:	e8 5e ef ff ff       	call   c00292e8 <msg>
  thread_set_priority (PRI_DEFAULT - 10);
c002a38a:	c7 04 24 15 00 00 00 	movl   $0x15,(%esp)
c002a391:	e8 7d 69 ff ff       	call   c0020d13 <thread_set_priority>
  msg ("Main thread should have priority %d.  Actual priority: %d.",
c002a396:	e8 8b 69 ff ff       	call   c0020d26 <thread_get_priority>
c002a39b:	83 c4 0c             	add    $0xc,%esp
c002a39e:	50                   	push   %eax
c002a39f:	6a 29                	push   $0x29
c002a3a1:	68 94 f2 02 c0       	push   $0xc002f294
c002a3a6:	e8 3d ef ff ff       	call   c00292e8 <msg>
  lock_release (&lock);
c002a3ab:	89 1c 24             	mov    %ebx,(%esp)
c002a3ae:	e8 a9 82 ff ff       	call   c002265c <lock_release>
  msg ("acquire must already have finished.");
c002a3b3:	c7 04 24 44 f6 02 c0 	movl   $0xc002f644,(%esp)
c002a3ba:	e8 29 ef ff ff       	call   c00292e8 <msg>
  msg ("Main thread should have priority %d.  Actual priority: %d.",
c002a3bf:	e8 62 69 ff ff       	call   c0020d26 <thread_get_priority>
c002a3c4:	83 c4 0c             	add    $0xc,%esp
c002a3c7:	50                   	push   %eax
c002a3c8:	6a 15                	push   $0x15
c002a3ca:	68 94 f2 02 c0       	push   $0xc002f294
c002a3cf:	e8 14 ef ff ff       	call   c00292e8 <msg>
}
c002a3d4:	83 c4 38             	add    $0x38,%esp
c002a3d7:	5b                   	pop    %ebx
c002a3d8:	c3                   	ret    
  ASSERT (!thread_mlfqs);
c002a3d9:	83 ec 0c             	sub    $0xc,%esp
c002a3dc:	68 98 ec 02 c0       	push   $0xc002ec98
c002a3e1:	68 9f cd 02 c0       	push   $0xc002cd9f
c002a3e6:	68 30 cc 02 c0       	push   $0xc002cc30
c002a3eb:	6a 15                	push   $0x15
c002a3ed:	68 18 f6 02 c0       	push   $0xc002f618
c002a3f2:	e8 18 d4 ff ff       	call   c002780f <debug_panic>
  ASSERT (thread_get_priority () == PRI_DEFAULT);
c002a3f7:	83 ec 0c             	sub    $0xc,%esp
c002a3fa:	68 2c f1 02 c0       	push   $0xc002f12c
c002a3ff:	68 9f cd 02 c0       	push   $0xc002cd9f
c002a404:	68 30 cc 02 c0       	push   $0xc002cc30
c002a409:	6a 18                	push   $0x18
c002a40b:	68 18 f6 02 c0       	push   $0xc002f618
c002a410:	e8 fa d3 ff ff       	call   c002780f <debug_panic>

c002a415 <simple_thread_func>:
    }
}

static void 
simple_thread_func (void *data_) 
{
c002a415:	56                   	push   %esi
c002a416:	53                   	push   %ebx
c002a417:	83 ec 04             	sub    $0x4,%esp
c002a41a:	8b 5c 24 10          	mov    0x10(%esp),%ebx
c002a41e:	be 10 00 00 00       	mov    $0x10,%esi
  struct simple_thread_data *data = data_;
  int i;
  
  for (i = 0; i < ITER_CNT; i++) 
    {
      lock_acquire (data->lock);
c002a423:	83 ec 0c             	sub    $0xc,%esp
c002a426:	ff 73 08             	pushl  0x8(%ebx)
c002a429:	e8 09 81 ff ff       	call   c0022537 <lock_acquire>
      *(*data->op)++ = data->id;
c002a42e:	8b 53 0c             	mov    0xc(%ebx),%edx
c002a431:	8b 02                	mov    (%edx),%eax
c002a433:	8d 48 04             	lea    0x4(%eax),%ecx
c002a436:	89 0a                	mov    %ecx,(%edx)
c002a438:	8b 13                	mov    (%ebx),%edx
c002a43a:	89 10                	mov    %edx,(%eax)
      lock_release (data->lock);
c002a43c:	83 c4 04             	add    $0x4,%esp
c002a43f:	ff 73 08             	pushl  0x8(%ebx)
c002a442:	e8 15 82 ff ff       	call   c002265c <lock_release>
      thread_yield ();
c002a447:	e8 b8 6b ff ff       	call   c0021004 <thread_yield>
  for (i = 0; i < ITER_CNT; i++) 
c002a44c:	83 c4 10             	add    $0x10,%esp
c002a44f:	4e                   	dec    %esi
c002a450:	75 d1                	jne    c002a423 <simple_thread_func+0xe>
    }
}
c002a452:	83 c4 04             	add    $0x4,%esp
c002a455:	5b                   	pop    %ebx
c002a456:	5e                   	pop    %esi
c002a457:	c3                   	ret    

c002a458 <test_priority_fifo>:
{
c002a458:	55                   	push   %ebp
c002a459:	57                   	push   %edi
c002a45a:	56                   	push   %esi
c002a45b:	53                   	push   %ebx
c002a45c:	81 ec 4c 01 00 00    	sub    $0x14c,%esp
  ASSERT (!thread_mlfqs);
c002a462:	80 3d ec 84 03 c0 00 	cmpb   $0x0,0xc00384ec
c002a469:	0f 85 f1 00 00 00    	jne    c002a560 <test_priority_fifo+0x108>
  ASSERT (thread_get_priority () == PRI_DEFAULT);
c002a46f:	e8 b2 68 ff ff       	call   c0020d26 <thread_get_priority>
c002a474:	83 f8 1f             	cmp    $0x1f,%eax
c002a477:	0f 85 01 01 00 00    	jne    c002a57e <test_priority_fifo+0x126>
  msg ("%d threads will iterate %d times in the same order each time.",
c002a47d:	83 ec 04             	sub    $0x4,%esp
c002a480:	6a 10                	push   $0x10
c002a482:	6a 10                	push   $0x10
c002a484:	68 cc f6 02 c0       	push   $0xc002f6cc
c002a489:	e8 5a ee ff ff       	call   c00292e8 <msg>
  msg ("If the order varies then there is a bug.");
c002a48e:	c7 04 24 0c f7 02 c0 	movl   $0xc002f70c,(%esp)
c002a495:	e8 4e ee ff ff       	call   c00292e8 <msg>
  output = op = malloc (sizeof *output * THREAD_CNT * ITER_CNT * 2);
c002a49a:	c7 04 24 00 08 00 00 	movl   $0x800,(%esp)
c002a4a1:	e8 dc 89 ff ff       	call   c0022e82 <malloc>
c002a4a6:	89 44 24 1c          	mov    %eax,0x1c(%esp)
c002a4aa:	89 44 24 34          	mov    %eax,0x34(%esp)
  ASSERT (output != NULL);
c002a4ae:	83 c4 10             	add    $0x10,%esp
c002a4b1:	85 c0                	test   %eax,%eax
c002a4b3:	0f 84 e3 00 00 00    	je     c002a59c <test_priority_fifo+0x144>
  lock_init (&lock);
c002a4b9:	83 ec 0c             	sub    $0xc,%esp
c002a4bc:	8d 44 24 34          	lea    0x34(%esp),%eax
c002a4c0:	50                   	push   %eax
c002a4c1:	e8 ef 7f ff ff       	call   c00224b5 <lock_init>
  thread_set_priority (PRI_DEFAULT + 2);
c002a4c6:	c7 04 24 21 00 00 00 	movl   $0x21,(%esp)
c002a4cd:	e8 41 68 ff ff       	call   c0020d13 <thread_set_priority>
c002a4d2:	8d 5c 24 50          	lea    0x50(%esp),%ebx
c002a4d6:	83 c4 10             	add    $0x10,%esp
  for (i = 0; i < THREAD_CNT; i++) 
c002a4d9:	be 00 00 00 00       	mov    $0x0,%esi
      snprintf (name, sizeof name, "%d", i);
c002a4de:	8d 7c 24 14          	lea    0x14(%esp),%edi
      d->lock = &lock;
c002a4e2:	8d 6c 24 28          	lea    0x28(%esp),%ebp
      snprintf (name, sizeof name, "%d", i);
c002a4e6:	56                   	push   %esi
c002a4e7:	68 ad ec 02 c0       	push   $0xc002ecad
c002a4ec:	6a 10                	push   $0x10
c002a4ee:	57                   	push   %edi
c002a4ef:	e8 f9 bf ff ff       	call   c00264ed <snprintf>
      d->id = i;
c002a4f4:	89 33                	mov    %esi,(%ebx)
      d->iterations = 0;
c002a4f6:	c7 43 04 00 00 00 00 	movl   $0x0,0x4(%ebx)
      d->lock = &lock;
c002a4fd:	89 6b 08             	mov    %ebp,0x8(%ebx)
      d->op = &op;
c002a500:	8d 44 24 34          	lea    0x34(%esp),%eax
c002a504:	89 43 0c             	mov    %eax,0xc(%ebx)
      thread_create (name, PRI_DEFAULT + 1, simple_thread_func, d);
c002a507:	53                   	push   %ebx
c002a508:	68 15 a4 02 c0       	push   $0xc002a415
c002a50d:	6a 20                	push   $0x20
c002a50f:	57                   	push   %edi
c002a510:	e8 25 65 ff ff       	call   c0020a3a <thread_create>
  for (i = 0; i < THREAD_CNT; i++) 
c002a515:	46                   	inc    %esi
c002a516:	83 c3 10             	add    $0x10,%ebx
c002a519:	83 c4 20             	add    $0x20,%esp
c002a51c:	83 fe 10             	cmp    $0x10,%esi
c002a51f:	75 c5                	jne    c002a4e6 <test_priority_fifo+0x8e>
  thread_set_priority (PRI_DEFAULT);
c002a521:	83 ec 0c             	sub    $0xc,%esp
c002a524:	6a 1f                	push   $0x1f
c002a526:	e8 e8 67 ff ff       	call   c0020d13 <thread_set_priority>
  ASSERT (lock.holder == NULL);
c002a52b:	83 c4 10             	add    $0x10,%esp
c002a52e:	83 7c 24 28 00       	cmpl   $0x0,0x28(%esp)
c002a533:	0f 85 81 00 00 00    	jne    c002a5ba <test_priority_fifo+0x162>
  for (; output < op; output++) 
c002a539:	8b 44 24 0c          	mov    0xc(%esp),%eax
c002a53d:	3b 44 24 24          	cmp    0x24(%esp),%eax
c002a541:	0f 83 0f 01 00 00    	jae    c002a656 <test_priority_fifo+0x1fe>
      ASSERT (*output >= 0 && *output < THREAD_CNT);
c002a547:	8b 18                	mov    (%eax),%ebx
c002a549:	83 fb 0f             	cmp    $0xf,%ebx
c002a54c:	0f 87 86 00 00 00    	ja     c002a5d8 <test_priority_fifo+0x180>
c002a552:	8b 7c 24 0c          	mov    0xc(%esp),%edi
c002a556:	be 00 00 00 00       	mov    $0x0,%esi
c002a55b:	e9 bb 00 00 00       	jmp    c002a61b <test_priority_fifo+0x1c3>
  ASSERT (!thread_mlfqs);
c002a560:	83 ec 0c             	sub    $0xc,%esp
c002a563:	68 98 ec 02 c0       	push   $0xc002ec98
c002a568:	68 9f cd 02 c0       	push   $0xc002cd9f
c002a56d:	68 4c cc 02 c0       	push   $0xc002cc4c
c002a572:	6a 28                	push   $0x28
c002a574:	68 a8 f6 02 c0       	push   $0xc002f6a8
c002a579:	e8 91 d2 ff ff       	call   c002780f <debug_panic>
  ASSERT (thread_get_priority () == PRI_DEFAULT);
c002a57e:	83 ec 0c             	sub    $0xc,%esp
c002a581:	68 2c f1 02 c0       	push   $0xc002f12c
c002a586:	68 9f cd 02 c0       	push   $0xc002cd9f
c002a58b:	68 4c cc 02 c0       	push   $0xc002cc4c
c002a590:	6a 2b                	push   $0x2b
c002a592:	68 a8 f6 02 c0       	push   $0xc002f6a8
c002a597:	e8 73 d2 ff ff       	call   c002780f <debug_panic>
  ASSERT (output != NULL);
c002a59c:	83 ec 0c             	sub    $0xc,%esp
c002a59f:	68 68 f6 02 c0       	push   $0xc002f668
c002a5a4:	68 9f cd 02 c0       	push   $0xc002cd9f
c002a5a9:	68 4c cc 02 c0       	push   $0xc002cc4c
c002a5ae:	6a 32                	push   $0x32
c002a5b0:	68 a8 f6 02 c0       	push   $0xc002f6a8
c002a5b5:	e8 55 d2 ff ff       	call   c002780f <debug_panic>
  ASSERT (lock.holder == NULL);
c002a5ba:	83 ec 0c             	sub    $0xc,%esp
c002a5bd:	68 77 f6 02 c0       	push   $0xc002f677
c002a5c2:	68 9f cd 02 c0       	push   $0xc002cd9f
c002a5c7:	68 4c cc 02 c0       	push   $0xc002cc4c
c002a5cc:	6a 44                	push   $0x44
c002a5ce:	68 a8 f6 02 c0       	push   $0xc002f6a8
c002a5d3:	e8 37 d2 ff ff       	call   c002780f <debug_panic>
      ASSERT (*output >= 0 && *output < THREAD_CNT);
c002a5d8:	83 ec 0c             	sub    $0xc,%esp
c002a5db:	68 38 f7 02 c0       	push   $0xc002f738
c002a5e0:	68 9f cd 02 c0       	push   $0xc002cd9f
c002a5e5:	68 4c cc 02 c0       	push   $0xc002cc4c
c002a5ea:	6a 4b                	push   $0x4b
c002a5ec:	68 a8 f6 02 c0       	push   $0xc002f6a8
c002a5f1:	e8 19 d2 ff ff       	call   c002780f <debug_panic>
        printf ("(priority-fifo) iteration:");
c002a5f6:	83 ec 0c             	sub    $0xc,%esp
c002a5f9:	68 8b f6 02 c0       	push   $0xc002f68b
c002a5fe:	e8 5e b7 ff ff       	call   c0025d61 <printf>
c002a603:	83 c4 10             	add    $0x10,%esp
c002a606:	eb 24                	jmp    c002a62c <test_priority_fifo+0x1d4>
      d->iterations++;
c002a608:	ff 43 04             	incl   0x4(%ebx)
  for (; output < op; output++) 
c002a60b:	83 c7 04             	add    $0x4,%edi
c002a60e:	39 7c 24 24          	cmp    %edi,0x24(%esp)
c002a612:	76 42                	jbe    c002a656 <test_priority_fifo+0x1fe>
      ASSERT (*output >= 0 && *output < THREAD_CNT);
c002a614:	8b 1f                	mov    (%edi),%ebx
c002a616:	83 fb 0f             	cmp    $0xf,%ebx
c002a619:	77 bd                	ja     c002a5d8 <test_priority_fifo+0x180>
      d = data + *output;
c002a61b:	c1 e3 04             	shl    $0x4,%ebx
c002a61e:	8d 44 24 40          	lea    0x40(%esp),%eax
c002a622:	01 c3                	add    %eax,%ebx
      if (cnt % THREAD_CNT == 0)
c002a624:	f7 c6 0f 00 00 00    	test   $0xf,%esi
c002a62a:	74 ca                	je     c002a5f6 <test_priority_fifo+0x19e>
      printf (" %d", d->id);
c002a62c:	83 ec 08             	sub    $0x8,%esp
c002a62f:	ff 33                	pushl  (%ebx)
c002a631:	68 ac ec 02 c0       	push   $0xc002ecac
c002a636:	e8 26 b7 ff ff       	call   c0025d61 <printf>
      if (++cnt % THREAD_CNT == 0)
c002a63b:	46                   	inc    %esi
c002a63c:	83 c4 10             	add    $0x10,%esp
c002a63f:	f7 c6 0f 00 00 00    	test   $0xf,%esi
c002a645:	75 c1                	jne    c002a608 <test_priority_fifo+0x1b0>
        printf ("\n");
c002a647:	83 ec 0c             	sub    $0xc,%esp
c002a64a:	6a 0a                	push   $0xa
c002a64c:	e8 78 ec ff ff       	call   c00292c9 <putchar>
c002a651:	83 c4 10             	add    $0x10,%esp
c002a654:	eb b2                	jmp    c002a608 <test_priority_fifo+0x1b0>
}
c002a656:	81 c4 4c 01 00 00    	add    $0x14c,%esp
c002a65c:	5b                   	pop    %ebx
c002a65d:	5e                   	pop    %esi
c002a65e:	5f                   	pop    %edi
c002a65f:	5d                   	pop    %ebp
c002a660:	c3                   	ret    

c002a661 <simple_thread_func>:
  msg ("The high-priority thread should have already completed.");
}

static void 
simple_thread_func (void *aux UNUSED) 
{
c002a661:	53                   	push   %ebx
c002a662:	83 ec 08             	sub    $0x8,%esp
  int i;
  
  for (i = 0; i < 5; i++) 
c002a665:	bb 00 00 00 00       	mov    $0x0,%ebx
    {
      msg ("Thread %s iteration %d", thread_name (), i);
c002a66a:	e8 8a 65 ff ff       	call   c0020bf9 <thread_name>
c002a66f:	83 ec 04             	sub    $0x4,%esp
c002a672:	53                   	push   %ebx
c002a673:	50                   	push   %eax
c002a674:	68 5d f7 02 c0       	push   $0xc002f75d
c002a679:	e8 6a ec ff ff       	call   c00292e8 <msg>
      thread_yield ();
c002a67e:	e8 81 69 ff ff       	call   c0021004 <thread_yield>
  for (i = 0; i < 5; i++) 
c002a683:	43                   	inc    %ebx
c002a684:	83 c4 10             	add    $0x10,%esp
c002a687:	83 fb 05             	cmp    $0x5,%ebx
c002a68a:	75 de                	jne    c002a66a <simple_thread_func+0x9>
    }
  msg ("Thread %s done!", thread_name ());
c002a68c:	e8 68 65 ff ff       	call   c0020bf9 <thread_name>
c002a691:	83 ec 08             	sub    $0x8,%esp
c002a694:	50                   	push   %eax
c002a695:	68 74 f7 02 c0       	push   $0xc002f774
c002a69a:	e8 49 ec ff ff       	call   c00292e8 <msg>
}
c002a69f:	83 c4 18             	add    $0x18,%esp
c002a6a2:	5b                   	pop    %ebx
c002a6a3:	c3                   	ret    

c002a6a4 <test_priority_preempt>:
{
c002a6a4:	83 ec 0c             	sub    $0xc,%esp
  ASSERT (!thread_mlfqs);
c002a6a7:	80 3d ec 84 03 c0 00 	cmpb   $0x0,0xc00384ec
c002a6ae:	75 2d                	jne    c002a6dd <test_priority_preempt+0x39>
  ASSERT (thread_get_priority () == PRI_DEFAULT);
c002a6b0:	e8 71 66 ff ff       	call   c0020d26 <thread_get_priority>
c002a6b5:	83 f8 1f             	cmp    $0x1f,%eax
c002a6b8:	75 41                	jne    c002a6fb <test_priority_preempt+0x57>
  thread_create ("high-priority", PRI_DEFAULT + 1, simple_thread_func, NULL);
c002a6ba:	6a 00                	push   $0x0
c002a6bc:	68 61 a6 02 c0       	push   $0xc002a661
c002a6c1:	6a 20                	push   $0x20
c002a6c3:	68 84 f7 02 c0       	push   $0xc002f784
c002a6c8:	e8 6d 63 ff ff       	call   c0020a3a <thread_create>
  msg ("The high-priority thread should have already completed.");
c002a6cd:	c7 04 24 bc f7 02 c0 	movl   $0xc002f7bc,(%esp)
c002a6d4:	e8 0f ec ff ff       	call   c00292e8 <msg>
}
c002a6d9:	83 c4 1c             	add    $0x1c,%esp
c002a6dc:	c3                   	ret    
  ASSERT (!thread_mlfqs);
c002a6dd:	83 ec 0c             	sub    $0xc,%esp
c002a6e0:	68 98 ec 02 c0       	push   $0xc002ec98
c002a6e5:	68 9f cd 02 c0       	push   $0xc002cd9f
c002a6ea:	68 60 cc 02 c0       	push   $0xc002cc60
c002a6ef:	6a 15                	push   $0x15
c002a6f1:	68 94 f7 02 c0       	push   $0xc002f794
c002a6f6:	e8 14 d1 ff ff       	call   c002780f <debug_panic>
  ASSERT (thread_get_priority () == PRI_DEFAULT);
c002a6fb:	83 ec 0c             	sub    $0xc,%esp
c002a6fe:	68 2c f1 02 c0       	push   $0xc002f12c
c002a703:	68 9f cd 02 c0       	push   $0xc002cd9f
c002a708:	68 60 cc 02 c0       	push   $0xc002cc60
c002a70d:	6a 18                	push   $0x18
c002a70f:	68 94 f7 02 c0       	push   $0xc002f794
c002a714:	e8 f6 d0 ff ff       	call   c002780f <debug_panic>

c002a719 <priority_sema_thread>:
    }
}

static void
priority_sema_thread (void *aux UNUSED) 
{
c002a719:	83 ec 18             	sub    $0x18,%esp
  sema_down (&sema);
c002a71c:	68 98 84 03 c0       	push   $0xc0038498
c002a721:	e8 9b 7b ff ff       	call   c00222c1 <sema_down>
  msg ("Thread %s woke up.", thread_name ());
c002a726:	e8 ce 64 ff ff       	call   c0020bf9 <thread_name>
c002a72b:	83 c4 08             	add    $0x8,%esp
c002a72e:	50                   	push   %eax
c002a72f:	68 80 ef 02 c0       	push   $0xc002ef80
c002a734:	e8 af eb ff ff       	call   c00292e8 <msg>
}
c002a739:	83 c4 1c             	add    $0x1c,%esp
c002a73c:	c3                   	ret    

c002a73d <test_priority_sema>:
{
c002a73d:	55                   	push   %ebp
c002a73e:	57                   	push   %edi
c002a73f:	56                   	push   %esi
c002a740:	53                   	push   %ebx
c002a741:	83 ec 1c             	sub    $0x1c,%esp
  ASSERT (!thread_mlfqs);
c002a744:	80 3d ec 84 03 c0 00 	cmpb   $0x0,0xc00384ec
c002a74b:	0f 85 87 00 00 00    	jne    c002a7d8 <test_priority_sema+0x9b>
  sema_init (&sema, 0);
c002a751:	83 ec 08             	sub    $0x8,%esp
c002a754:	6a 00                	push   $0x0
c002a756:	68 98 84 03 c0       	push   $0xc0038498
c002a75b:	e8 22 7b ff ff       	call   c0022282 <sema_init>
  thread_set_priority (PRI_MIN);
c002a760:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
c002a767:	e8 a7 65 ff ff       	call   c0020d13 <thread_set_priority>
c002a76c:	83 c4 10             	add    $0x10,%esp
c002a76f:	bb 03 00 00 00       	mov    $0x3,%ebx
      int priority = PRI_DEFAULT - (i + 3) % 10 - 1;
c002a774:	bd 0a 00 00 00       	mov    $0xa,%ebp
      snprintf (name, sizeof name, "priority %d", priority);
c002a779:	89 e7                	mov    %esp,%edi
      int priority = PRI_DEFAULT - (i + 3) % 10 - 1;
c002a77b:	89 d8                	mov    %ebx,%eax
c002a77d:	99                   	cltd   
c002a77e:	f7 fd                	idiv   %ebp
c002a780:	be 1e 00 00 00       	mov    $0x1e,%esi
c002a785:	29 d6                	sub    %edx,%esi
      snprintf (name, sizeof name, "priority %d", priority);
c002a787:	56                   	push   %esi
c002a788:	68 93 ef 02 c0       	push   $0xc002ef93
c002a78d:	6a 10                	push   $0x10
c002a78f:	57                   	push   %edi
c002a790:	e8 58 bd ff ff       	call   c00264ed <snprintf>
      thread_create (name, priority, priority_sema_thread, NULL);
c002a795:	6a 00                	push   $0x0
c002a797:	68 19 a7 02 c0       	push   $0xc002a719
c002a79c:	56                   	push   %esi
c002a79d:	57                   	push   %edi
c002a79e:	e8 97 62 ff ff       	call   c0020a3a <thread_create>
c002a7a3:	43                   	inc    %ebx
  for (i = 0; i < 10; i++) 
c002a7a4:	83 c4 20             	add    $0x20,%esp
c002a7a7:	83 fb 0d             	cmp    $0xd,%ebx
c002a7aa:	75 cf                	jne    c002a77b <test_priority_sema+0x3e>
c002a7ac:	bb 0a 00 00 00       	mov    $0xa,%ebx
      sema_up (&sema);
c002a7b1:	83 ec 0c             	sub    $0xc,%esp
c002a7b4:	68 98 84 03 c0       	push   $0xc0038498
c002a7b9:	e8 e4 7b ff ff       	call   c00223a2 <sema_up>
      msg ("Back in main thread."); 
c002a7be:	c7 04 24 f4 f7 02 c0 	movl   $0xc002f7f4,(%esp)
c002a7c5:	e8 1e eb ff ff       	call   c00292e8 <msg>
  for (i = 0; i < 10; i++) 
c002a7ca:	83 c4 10             	add    $0x10,%esp
c002a7cd:	4b                   	dec    %ebx
c002a7ce:	75 e1                	jne    c002a7b1 <test_priority_sema+0x74>
}
c002a7d0:	83 c4 1c             	add    $0x1c,%esp
c002a7d3:	5b                   	pop    %ebx
c002a7d4:	5e                   	pop    %esi
c002a7d5:	5f                   	pop    %edi
c002a7d6:	5d                   	pop    %ebp
c002a7d7:	c3                   	ret    
  ASSERT (!thread_mlfqs);
c002a7d8:	83 ec 0c             	sub    $0xc,%esp
c002a7db:	68 98 ec 02 c0       	push   $0xc002ec98
c002a7e0:	68 9f cd 02 c0       	push   $0xc002cd9f
c002a7e5:	68 78 cc 02 c0       	push   $0xc002cc78
c002a7ea:	6a 15                	push   $0x15
c002a7ec:	68 0c f8 02 c0       	push   $0xc002f80c
c002a7f1:	e8 19 d0 ff ff       	call   c002780f <debug_panic>

c002a7f6 <priority_condvar_thread>:
    }
}

static void
priority_condvar_thread (void *aux UNUSED) 
{
c002a7f6:	83 ec 0c             	sub    $0xc,%esp
  msg ("Thread %s starting.", thread_name ());
c002a7f9:	e8 fb 63 ff ff       	call   c0020bf9 <thread_name>
c002a7fe:	83 ec 08             	sub    $0x8,%esp
c002a801:	50                   	push   %eax
c002a802:	68 30 f8 02 c0       	push   $0xc002f830
c002a807:	e8 dc ea ff ff       	call   c00292e8 <msg>
  lock_acquire (&lock);
c002a80c:	c7 04 24 bc 84 03 c0 	movl   $0xc00384bc,(%esp)
c002a813:	e8 1f 7d ff ff       	call   c0022537 <lock_acquire>
  cond_wait (&condition, &lock);
c002a818:	83 c4 08             	add    $0x8,%esp
c002a81b:	68 bc 84 03 c0       	push   $0xc00384bc
c002a820:	68 ac 84 03 c0       	push   $0xc00384ac
c002a825:	e8 e0 7e ff ff       	call   c002270a <cond_wait>
  msg ("Thread %s woke up.", thread_name ());
c002a82a:	e8 ca 63 ff ff       	call   c0020bf9 <thread_name>
c002a82f:	83 c4 08             	add    $0x8,%esp
c002a832:	50                   	push   %eax
c002a833:	68 80 ef 02 c0       	push   $0xc002ef80
c002a838:	e8 ab ea ff ff       	call   c00292e8 <msg>
  lock_release (&lock);
c002a83d:	c7 04 24 bc 84 03 c0 	movl   $0xc00384bc,(%esp)
c002a844:	e8 13 7e ff ff       	call   c002265c <lock_release>
}
c002a849:	83 c4 1c             	add    $0x1c,%esp
c002a84c:	c3                   	ret    

c002a84d <test_priority_condvar>:
{
c002a84d:	55                   	push   %ebp
c002a84e:	57                   	push   %edi
c002a84f:	56                   	push   %esi
c002a850:	53                   	push   %ebx
c002a851:	83 ec 1c             	sub    $0x1c,%esp
  ASSERT (!thread_mlfqs);
c002a854:	80 3d ec 84 03 c0 00 	cmpb   $0x0,0xc00384ec
c002a85b:	0f 85 af 00 00 00    	jne    c002a910 <test_priority_condvar+0xc3>
  lock_init (&lock);
c002a861:	83 ec 0c             	sub    $0xc,%esp
c002a864:	68 bc 84 03 c0       	push   $0xc00384bc
c002a869:	e8 47 7c ff ff       	call   c00224b5 <lock_init>
  cond_init (&condition);
c002a86e:	c7 04 24 ac 84 03 c0 	movl   $0xc00384ac,(%esp)
c002a875:	e8 57 7e ff ff       	call   c00226d1 <cond_init>
  thread_set_priority (PRI_MIN);
c002a87a:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
c002a881:	e8 8d 64 ff ff       	call   c0020d13 <thread_set_priority>
c002a886:	83 c4 10             	add    $0x10,%esp
c002a889:	bb 07 00 00 00       	mov    $0x7,%ebx
      int priority = PRI_DEFAULT - (i + 7) % 10 - 1;
c002a88e:	bd 0a 00 00 00       	mov    $0xa,%ebp
      snprintf (name, sizeof name, "priority %d", priority);
c002a893:	89 e7                	mov    %esp,%edi
      int priority = PRI_DEFAULT - (i + 7) % 10 - 1;
c002a895:	89 d8                	mov    %ebx,%eax
c002a897:	99                   	cltd   
c002a898:	f7 fd                	idiv   %ebp
c002a89a:	be 1e 00 00 00       	mov    $0x1e,%esi
c002a89f:	29 d6                	sub    %edx,%esi
      snprintf (name, sizeof name, "priority %d", priority);
c002a8a1:	56                   	push   %esi
c002a8a2:	68 93 ef 02 c0       	push   $0xc002ef93
c002a8a7:	6a 10                	push   $0x10
c002a8a9:	57                   	push   %edi
c002a8aa:	e8 3e bc ff ff       	call   c00264ed <snprintf>
      thread_create (name, priority, priority_condvar_thread, NULL);
c002a8af:	6a 00                	push   $0x0
c002a8b1:	68 f6 a7 02 c0       	push   $0xc002a7f6
c002a8b6:	56                   	push   %esi
c002a8b7:	57                   	push   %edi
c002a8b8:	e8 7d 61 ff ff       	call   c0020a3a <thread_create>
c002a8bd:	43                   	inc    %ebx
  for (i = 0; i < 10; i++) 
c002a8be:	83 c4 20             	add    $0x20,%esp
c002a8c1:	83 fb 11             	cmp    $0x11,%ebx
c002a8c4:	75 cf                	jne    c002a895 <test_priority_condvar+0x48>
c002a8c6:	bb 0a 00 00 00       	mov    $0xa,%ebx
      lock_acquire (&lock);
c002a8cb:	83 ec 0c             	sub    $0xc,%esp
c002a8ce:	68 bc 84 03 c0       	push   $0xc00384bc
c002a8d3:	e8 5f 7c ff ff       	call   c0022537 <lock_acquire>
      msg ("Signaling...");
c002a8d8:	c7 04 24 44 f8 02 c0 	movl   $0xc002f844,(%esp)
c002a8df:	e8 04 ea ff ff       	call   c00292e8 <msg>
      cond_signal (&condition, &lock);
c002a8e4:	83 c4 08             	add    $0x8,%esp
c002a8e7:	68 bc 84 03 c0       	push   $0xc00384bc
c002a8ec:	68 ac 84 03 c0       	push   $0xc00384ac
c002a8f1:	e8 0d 7f ff ff       	call   c0022803 <cond_signal>
      lock_release (&lock);
c002a8f6:	c7 04 24 bc 84 03 c0 	movl   $0xc00384bc,(%esp)
c002a8fd:	e8 5a 7d ff ff       	call   c002265c <lock_release>
  for (i = 0; i < 10; i++) 
c002a902:	83 c4 10             	add    $0x10,%esp
c002a905:	4b                   	dec    %ebx
c002a906:	75 c3                	jne    c002a8cb <test_priority_condvar+0x7e>
}
c002a908:	83 c4 1c             	add    $0x1c,%esp
c002a90b:	5b                   	pop    %ebx
c002a90c:	5e                   	pop    %esi
c002a90d:	5f                   	pop    %edi
c002a90e:	5d                   	pop    %ebp
c002a90f:	c3                   	ret    
  ASSERT (!thread_mlfqs);
c002a910:	83 ec 0c             	sub    $0xc,%esp
c002a913:	68 98 ec 02 c0       	push   $0xc002ec98
c002a918:	68 9f cd 02 c0       	push   $0xc002cd9f
c002a91d:	68 8c cc 02 c0       	push   $0xc002cc8c
c002a922:	6a 16                	push   $0x16
c002a924:	68 54 f8 02 c0       	push   $0xc002f854
c002a929:	e8 e1 ce ff ff       	call   c002780f <debug_panic>

c002a92e <interloper_thread_func>:
                                         thread_get_priority ());
}

static void
interloper_thread_func (void *arg_ UNUSED)
{
c002a92e:	83 ec 0c             	sub    $0xc,%esp
  msg ("%s finished.", thread_name ());
c002a931:	e8 c3 62 ff ff       	call   c0020bf9 <thread_name>
c002a936:	83 ec 08             	sub    $0x8,%esp
c002a939:	50                   	push   %eax
c002a93a:	68 7b f8 02 c0       	push   $0xc002f87b
c002a93f:	e8 a4 e9 ff ff       	call   c00292e8 <msg>
}
c002a944:	83 c4 1c             	add    $0x1c,%esp
c002a947:	c3                   	ret    

c002a948 <donor_thread_func>:
{
c002a948:	56                   	push   %esi
c002a949:	53                   	push   %ebx
c002a94a:	83 ec 04             	sub    $0x4,%esp
c002a94d:	8b 5c 24 10          	mov    0x10(%esp),%ebx
  if (locks->first)
c002a951:	8b 43 04             	mov    0x4(%ebx),%eax
c002a954:	85 c0                	test   %eax,%eax
c002a956:	74 0c                	je     c002a964 <donor_thread_func+0x1c>
    lock_acquire (locks->first);
c002a958:	83 ec 0c             	sub    $0xc,%esp
c002a95b:	50                   	push   %eax
c002a95c:	e8 d6 7b ff ff       	call   c0022537 <lock_acquire>
c002a961:	83 c4 10             	add    $0x10,%esp
  lock_acquire (locks->second);
c002a964:	83 ec 0c             	sub    $0xc,%esp
c002a967:	ff 33                	pushl  (%ebx)
c002a969:	e8 c9 7b ff ff       	call   c0022537 <lock_acquire>
  msg ("%s got lock", thread_name ());
c002a96e:	e8 86 62 ff ff       	call   c0020bf9 <thread_name>
c002a973:	83 c4 08             	add    $0x8,%esp
c002a976:	50                   	push   %eax
c002a977:	68 88 f8 02 c0       	push   $0xc002f888
c002a97c:	e8 67 e9 ff ff       	call   c00292e8 <msg>
  lock_release (locks->second);
c002a981:	83 c4 04             	add    $0x4,%esp
c002a984:	ff 33                	pushl  (%ebx)
c002a986:	e8 d1 7c ff ff       	call   c002265c <lock_release>
  msg ("%s should have priority %d. Actual priority: %d", 
c002a98b:	e8 96 63 ff ff       	call   c0020d26 <thread_get_priority>
c002a990:	89 c6                	mov    %eax,%esi
c002a992:	e8 62 62 ff ff       	call   c0020bf9 <thread_name>
c002a997:	56                   	push   %esi
c002a998:	6a 15                	push   $0x15
c002a99a:	50                   	push   %eax
c002a99b:	68 b0 f8 02 c0       	push   $0xc002f8b0
c002a9a0:	e8 43 e9 ff ff       	call   c00292e8 <msg>
  if (locks->first)
c002a9a5:	8b 43 04             	mov    0x4(%ebx),%eax
c002a9a8:	83 c4 20             	add    $0x20,%esp
c002a9ab:	85 c0                	test   %eax,%eax
c002a9ad:	74 0c                	je     c002a9bb <donor_thread_func+0x73>
    lock_release (locks->first);
c002a9af:	83 ec 0c             	sub    $0xc,%esp
c002a9b2:	50                   	push   %eax
c002a9b3:	e8 a4 7c ff ff       	call   c002265c <lock_release>
c002a9b8:	83 c4 10             	add    $0x10,%esp
  msg ("%s finishing with priority %d.", thread_name (),
c002a9bb:	e8 66 63 ff ff       	call   c0020d26 <thread_get_priority>
c002a9c0:	89 c3                	mov    %eax,%ebx
c002a9c2:	e8 32 62 ff ff       	call   c0020bf9 <thread_name>
c002a9c7:	83 ec 04             	sub    $0x4,%esp
c002a9ca:	53                   	push   %ebx
c002a9cb:	50                   	push   %eax
c002a9cc:	68 e0 f8 02 c0       	push   $0xc002f8e0
c002a9d1:	e8 12 e9 ff ff       	call   c00292e8 <msg>
}
c002a9d6:	83 c4 14             	add    $0x14,%esp
c002a9d9:	5b                   	pop    %ebx
c002a9da:	5e                   	pop    %esi
c002a9db:	c3                   	ret    

c002a9dc <test_priority_donate_chain>:
{
c002a9dc:	55                   	push   %ebp
c002a9dd:	57                   	push   %edi
c002a9de:	56                   	push   %esi
c002a9df:	53                   	push   %ebx
c002a9e0:	81 ec 1c 01 00 00    	sub    $0x11c,%esp
  ASSERT (!thread_mlfqs);
c002a9e6:	80 3d ec 84 03 c0 00 	cmpb   $0x0,0xc00384ec
c002a9ed:	75 73                	jne    c002aa62 <test_priority_donate_chain+0x86>
  thread_set_priority (PRI_MIN);
c002a9ef:	83 ec 0c             	sub    $0xc,%esp
c002a9f2:	6a 00                	push   $0x0
c002a9f4:	e8 1a 63 ff ff       	call   c0020d13 <thread_set_priority>
c002a9f9:	8d 5c 24 78          	lea    0x78(%esp),%ebx
c002a9fd:	8d b4 24 20 01 00 00 	lea    0x120(%esp),%esi
c002aa04:	83 c4 10             	add    $0x10,%esp
    lock_init (&locks[i]);
c002aa07:	83 ec 0c             	sub    $0xc,%esp
c002aa0a:	53                   	push   %ebx
c002aa0b:	e8 a5 7a ff ff       	call   c00224b5 <lock_init>
c002aa10:	83 c3 18             	add    $0x18,%ebx
  for (i = 0; i < NESTING_DEPTH - 1; i++)
c002aa13:	83 c4 10             	add    $0x10,%esp
c002aa16:	39 f3                	cmp    %esi,%ebx
c002aa18:	75 ed                	jne    c002aa07 <test_priority_donate_chain+0x2b>
  lock_acquire (&locks[0]);
c002aa1a:	83 ec 0c             	sub    $0xc,%esp
c002aa1d:	8d 44 24 74          	lea    0x74(%esp),%eax
c002aa21:	50                   	push   %eax
c002aa22:	e8 10 7b ff ff       	call   c0022537 <lock_acquire>
  msg ("%s got lock.", thread_name ());
c002aa27:	e8 cd 61 ff ff       	call   c0020bf9 <thread_name>
c002aa2c:	83 c4 08             	add    $0x8,%esp
c002aa2f:	50                   	push   %eax
c002aa30:	68 94 f8 02 c0       	push   $0xc002f894
c002aa35:	e8 ae e8 ff ff       	call   c00292e8 <msg>
c002aa3a:	8d 84 24 90 00 00 00 	lea    0x90(%esp),%eax
c002aa41:	89 44 24 14          	mov    %eax,0x14(%esp)
c002aa45:	8d 74 24 40          	lea    0x40(%esp),%esi
c002aa49:	83 c4 10             	add    $0x10,%esp
c002aa4c:	c7 44 24 08 02 00 00 	movl   $0x2,0x8(%esp)
c002aa53:	00 
  for (i = 1; i < NESTING_DEPTH; i++)
c002aa54:	bb 01 00 00 00       	mov    $0x1,%ebx
      snprintf (name, sizeof name, "thread %d", i);
c002aa59:	8d 6c 24 18          	lea    0x18(%esp),%ebp
c002aa5d:	e9 97 00 00 00       	jmp    c002aaf9 <test_priority_donate_chain+0x11d>
  ASSERT (!thread_mlfqs);
c002aa62:	83 ec 0c             	sub    $0xc,%esp
c002aa65:	68 98 ec 02 c0       	push   $0xc002ec98
c002aa6a:	68 9f cd 02 c0       	push   $0xc002cd9f
c002aa6f:	68 a4 cc 02 c0       	push   $0xc002cca4
c002aa74:	6a 34                	push   $0x34
c002aa76:	68 00 f9 02 c0       	push   $0xc002f900
c002aa7b:	e8 8f cd ff ff       	call   c002780f <debug_panic>
      lock_pairs[i].first = i < NESTING_DEPTH - 1 ? locks + i: NULL;
c002aa80:	b8 00 00 00 00       	mov    $0x0,%eax
c002aa85:	89 46 04             	mov    %eax,0x4(%esi)
      lock_pairs[i].second = locks + i - 1;
c002aa88:	8b 44 24 04          	mov    0x4(%esp),%eax
c002aa8c:	83 e8 18             	sub    $0x18,%eax
c002aa8f:	89 06                	mov    %eax,(%esi)
      thread_create (name, thread_priority, donor_thread_func, lock_pairs + i);
c002aa91:	56                   	push   %esi
c002aa92:	68 48 a9 02 c0       	push   $0xc002a948
c002aa97:	57                   	push   %edi
c002aa98:	55                   	push   %ebp
c002aa99:	e8 9c 5f ff ff       	call   c0020a3a <thread_create>
      msg ("%s should have priority %d.  Actual priority: %d.",
c002aa9e:	e8 83 62 ff ff       	call   c0020d26 <thread_get_priority>
c002aaa3:	89 44 24 1c          	mov    %eax,0x1c(%esp)
c002aaa7:	e8 4d 61 ff ff       	call   c0020bf9 <thread_name>
c002aaac:	ff 74 24 1c          	pushl  0x1c(%esp)
c002aab0:	57                   	push   %edi
c002aab1:	50                   	push   %eax
c002aab2:	68 2c f9 02 c0       	push   $0xc002f92c
c002aab7:	e8 2c e8 ff ff       	call   c00292e8 <msg>
      snprintf (name, sizeof name, "interloper %d", i);
c002aabc:	83 c4 20             	add    $0x20,%esp
c002aabf:	53                   	push   %ebx
c002aac0:	68 a1 f8 02 c0       	push   $0xc002f8a1
c002aac5:	6a 10                	push   $0x10
c002aac7:	55                   	push   %ebp
c002aac8:	e8 20 ba ff ff       	call   c00264ed <snprintf>
      thread_create (name, thread_priority - 1, interloper_thread_func, NULL);
c002aacd:	6a 00                	push   $0x0
c002aacf:	68 2e a9 02 c0       	push   $0xc002a92e
c002aad4:	8b 7c 24 20          	mov    0x20(%esp),%edi
c002aad8:	57                   	push   %edi
c002aad9:	55                   	push   %ebp
c002aada:	e8 5b 5f ff ff       	call   c0020a3a <thread_create>
  for (i = 1; i < NESTING_DEPTH; i++)
c002aadf:	43                   	inc    %ebx
c002aae0:	83 44 24 24 18       	addl   $0x18,0x24(%esp)
c002aae5:	83 c6 08             	add    $0x8,%esi
c002aae8:	89 f8                	mov    %edi,%eax
c002aaea:	83 c0 03             	add    $0x3,%eax
c002aaed:	89 44 24 28          	mov    %eax,0x28(%esp)
c002aaf1:	83 c4 20             	add    $0x20,%esp
c002aaf4:	83 fb 08             	cmp    $0x8,%ebx
c002aaf7:	74 29                	je     c002ab22 <test_priority_donate_chain+0x146>
      snprintf (name, sizeof name, "thread %d", i);
c002aaf9:	53                   	push   %ebx
c002aafa:	68 a6 ec 02 c0       	push   $0xc002eca6
c002aaff:	6a 10                	push   $0x10
c002ab01:	55                   	push   %ebp
c002ab02:	e8 e6 b9 ff ff       	call   c00264ed <snprintf>
c002ab07:	8d 04 1b             	lea    (%ebx,%ebx,1),%eax
c002ab0a:	8d 3c 18             	lea    (%eax,%ebx,1),%edi
      lock_pairs[i].first = i < NESTING_DEPTH - 1 ? locks + i: NULL;
c002ab0d:	83 c4 10             	add    $0x10,%esp
c002ab10:	83 fb 06             	cmp    $0x6,%ebx
c002ab13:	0f 8f 67 ff ff ff    	jg     c002aa80 <test_priority_donate_chain+0xa4>
c002ab19:	8b 44 24 04          	mov    0x4(%esp),%eax
c002ab1d:	e9 63 ff ff ff       	jmp    c002aa85 <test_priority_donate_chain+0xa9>
  lock_release (&locks[0]);
c002ab22:	83 ec 0c             	sub    $0xc,%esp
c002ab25:	8d 44 24 74          	lea    0x74(%esp),%eax
c002ab29:	50                   	push   %eax
c002ab2a:	e8 2d 7b ff ff       	call   c002265c <lock_release>
  msg ("%s finishing with priority %d.", thread_name (),
c002ab2f:	e8 f2 61 ff ff       	call   c0020d26 <thread_get_priority>
c002ab34:	89 c3                	mov    %eax,%ebx
c002ab36:	e8 be 60 ff ff       	call   c0020bf9 <thread_name>
c002ab3b:	83 c4 0c             	add    $0xc,%esp
c002ab3e:	53                   	push   %ebx
c002ab3f:	50                   	push   %eax
c002ab40:	68 e0 f8 02 c0       	push   $0xc002f8e0
c002ab45:	e8 9e e7 ff ff       	call   c00292e8 <msg>
}
c002ab4a:	81 c4 2c 01 00 00    	add    $0x12c,%esp
c002ab50:	5b                   	pop    %ebx
c002ab51:	5e                   	pop    %esi
c002ab52:	5f                   	pop    %edi
c002ab53:	5d                   	pop    %ebp
c002ab54:	c3                   	ret    

c002ab55 <test_mlfqs_load_1>:
#include "threads/thread.h"
#include "devices/timer.h"

void
test_mlfqs_load_1 (void) 
{
c002ab55:	55                   	push   %ebp
c002ab56:	57                   	push   %edi
c002ab57:	56                   	push   %esi
c002ab58:	53                   	push   %ebx
c002ab59:	83 ec 0c             	sub    $0xc,%esp
  int64_t start_time;
  int elapsed;
  int load_avg;
  
  ASSERT (thread_mlfqs);
c002ab5c:	80 3d ec 84 03 c0 00 	cmpb   $0x0,0xc00384ec
c002ab63:	74 1b                	je     c002ab80 <test_mlfqs_load_1+0x2b>

  msg ("spinning for up to 45 seconds, please wait...");
c002ab65:	83 ec 0c             	sub    $0xc,%esp
c002ab68:	68 ac f9 02 c0       	push   $0xc002f9ac
c002ab6d:	e8 76 e7 ff ff       	call   c00292e8 <msg>

  start_time = timer_ticks ();
c002ab72:	e8 e8 88 ff ff       	call   c002345f <timer_ticks>
c002ab77:	89 c6                	mov    %eax,%esi
c002ab79:	89 d7                	mov    %edx,%edi
c002ab7b:	83 c4 10             	add    $0x10,%esp
c002ab7e:	eb 6a                	jmp    c002abea <test_mlfqs_load_1+0x95>
  ASSERT (thread_mlfqs);
c002ab80:	83 ec 0c             	sub    $0xc,%esp
c002ab83:	68 99 ec 02 c0       	push   $0xc002ec99
c002ab88:	68 9f cd 02 c0       	push   $0xc002cd9f
c002ab8d:	68 c0 cc 02 c0       	push   $0xc002ccc0
c002ab92:	6a 18                	push   $0x18
c002ab94:	68 88 f9 02 c0       	push   $0xc002f988
c002ab99:	e8 71 cc ff ff       	call   c002780f <debug_panic>
  for (;;) 
    {
      load_avg = thread_get_load_avg ();
      ASSERT (load_avg >= 0);
c002ab9e:	83 ec 0c             	sub    $0xc,%esp
c002aba1:	68 5e f9 02 c0       	push   $0xc002f95e
c002aba6:	68 9f cd 02 c0       	push   $0xc002cd9f
c002abab:	68 c0 cc 02 c0       	push   $0xc002ccc0
c002abb0:	6a 20                	push   $0x20
c002abb2:	68 88 f9 02 c0       	push   $0xc002f988
c002abb7:	e8 53 cc ff ff       	call   c002780f <debug_panic>
      elapsed = timer_elapsed (start_time) / TIMER_FREQ;
      if (load_avg > 100)
        fail ("load average is %d.%02d "
c002abbc:	50                   	push   %eax
c002abbd:	b8 1f 85 eb 51       	mov    $0x51eb851f,%eax
c002abc2:	f7 eb                	imul   %ebx
c002abc4:	89 d0                	mov    %edx,%eax
c002abc6:	c1 f8 05             	sar    $0x5,%eax
c002abc9:	89 da                	mov    %ebx,%edx
c002abcb:	c1 fa 1f             	sar    $0x1f,%edx
c002abce:	29 d0                	sub    %edx,%eax
c002abd0:	8d 14 80             	lea    (%eax,%eax,4),%edx
c002abd3:	8d 14 92             	lea    (%edx,%edx,4),%edx
c002abd6:	c1 e2 02             	shl    $0x2,%edx
c002abd9:	29 d3                	sub    %edx,%ebx
c002abdb:	53                   	push   %ebx
c002abdc:	50                   	push   %eax
c002abdd:	68 dc f9 02 c0       	push   $0xc002f9dc
c002abe2:	e8 a5 e7 ff ff       	call   c002938c <fail>
c002abe7:	83 c4 10             	add    $0x10,%esp
      load_avg = thread_get_load_avg ();
c002abea:	e8 4d 61 ff ff       	call   c0020d3c <thread_get_load_avg>
c002abef:	89 c3                	mov    %eax,%ebx
      ASSERT (load_avg >= 0);
c002abf1:	85 c0                	test   %eax,%eax
c002abf3:	78 a9                	js     c002ab9e <test_mlfqs_load_1+0x49>
      elapsed = timer_elapsed (start_time) / TIMER_FREQ;
c002abf5:	83 ec 08             	sub    $0x8,%esp
c002abf8:	57                   	push   %edi
c002abf9:	56                   	push   %esi
c002abfa:	e8 89 88 ff ff       	call   c0023488 <timer_elapsed>
c002abff:	6a 00                	push   $0x0
c002ac01:	6a 64                	push   $0x64
c002ac03:	52                   	push   %edx
c002ac04:	50                   	push   %eax
c002ac05:	e8 1f c6 ff ff       	call   c0027229 <__divdi3>
c002ac0a:	89 c5                	mov    %eax,%ebp
      if (load_avg > 100)
c002ac0c:	83 c4 20             	add    $0x20,%esp
c002ac0f:	83 fb 64             	cmp    $0x64,%ebx
c002ac12:	7f a8                	jg     c002abbc <test_mlfqs_load_1+0x67>
              "but should be between 0 and 1 (after %d seconds)",
              load_avg / 100, load_avg % 100, elapsed);
      else if (load_avg > 50)
c002ac14:	83 fb 32             	cmp    $0x32,%ebx
c002ac17:	7f 17                	jg     c002ac30 <test_mlfqs_load_1+0xdb>
        break;
      else if (elapsed > 45)
c002ac19:	83 f8 2d             	cmp    $0x2d,%eax
c002ac1c:	7e cc                	jle    c002abea <test_mlfqs_load_1+0x95>
        fail ("load average stayed below 0.5 for more than 45 seconds");
c002ac1e:	83 ec 0c             	sub    $0xc,%esp
c002ac21:	68 28 fa 02 c0       	push   $0xc002fa28
c002ac26:	e8 61 e7 ff ff       	call   c002938c <fail>
c002ac2b:	83 c4 10             	add    $0x10,%esp
c002ac2e:	eb ba                	jmp    c002abea <test_mlfqs_load_1+0x95>
    }

  if (elapsed < 38)
c002ac30:	83 f8 25             	cmp    $0x25,%eax
c002ac33:	7e 76                	jle    c002acab <test_mlfqs_load_1+0x156>
    fail ("load average took only %d seconds to rise above 0.5", elapsed);
  msg ("load average rose to 0.5 after %d seconds", elapsed);
c002ac35:	83 ec 08             	sub    $0x8,%esp
c002ac38:	55                   	push   %ebp
c002ac39:	68 94 fa 02 c0       	push   $0xc002fa94
c002ac3e:	e8 a5 e6 ff ff       	call   c00292e8 <msg>

  msg ("sleeping for another 10 seconds, please wait...");
c002ac43:	c7 04 24 c0 fa 02 c0 	movl   $0xc002fac0,(%esp)
c002ac4a:	e8 99 e6 ff ff       	call   c00292e8 <msg>
  timer_sleep (TIMER_FREQ * 10);
c002ac4f:	83 c4 08             	add    $0x8,%esp
c002ac52:	6a 00                	push   $0x0
c002ac54:	68 e8 03 00 00       	push   $0x3e8
c002ac59:	e8 46 88 ff ff       	call   c00234a4 <timer_sleep>

  load_avg = thread_get_load_avg ();
c002ac5e:	e8 d9 60 ff ff       	call   c0020d3c <thread_get_load_avg>
c002ac63:	89 c3                	mov    %eax,%ebx
  if (load_avg < 0)
c002ac65:	83 c4 10             	add    $0x10,%esp
c002ac68:	85 c0                	test   %eax,%eax
c002ac6a:	78 55                	js     c002acc1 <test_mlfqs_load_1+0x16c>
    fail ("load average fell below 0");
  if (load_avg > 50)
c002ac6c:	83 fb 32             	cmp    $0x32,%ebx
c002ac6f:	7f 62                	jg     c002acd3 <test_mlfqs_load_1+0x17e>
    fail ("load average stayed above 0.5 for more than 10 seconds");
  msg ("load average fell back below 0.5 (to %d.%02d)",
c002ac71:	83 ec 04             	sub    $0x4,%esp
c002ac74:	b8 1f 85 eb 51       	mov    $0x51eb851f,%eax
c002ac79:	f7 eb                	imul   %ebx
c002ac7b:	89 d0                	mov    %edx,%eax
c002ac7d:	c1 f8 05             	sar    $0x5,%eax
c002ac80:	89 da                	mov    %ebx,%edx
c002ac82:	c1 fa 1f             	sar    $0x1f,%edx
c002ac85:	29 d0                	sub    %edx,%eax
c002ac87:	8d 14 80             	lea    (%eax,%eax,4),%edx
c002ac8a:	8d 14 92             	lea    (%edx,%edx,4),%edx
c002ac8d:	c1 e2 02             	shl    $0x2,%edx
c002ac90:	29 d3                	sub    %edx,%ebx
c002ac92:	53                   	push   %ebx
c002ac93:	50                   	push   %eax
c002ac94:	68 28 fb 02 c0       	push   $0xc002fb28
c002ac99:	e8 4a e6 ff ff       	call   c00292e8 <msg>
       load_avg / 100, load_avg % 100);

  pass ();
c002ac9e:	e8 2f e7 ff ff       	call   c00293d2 <pass>
}
c002aca3:	83 c4 1c             	add    $0x1c,%esp
c002aca6:	5b                   	pop    %ebx
c002aca7:	5e                   	pop    %esi
c002aca8:	5f                   	pop    %edi
c002aca9:	5d                   	pop    %ebp
c002acaa:	c3                   	ret    
    fail ("load average took only %d seconds to rise above 0.5", elapsed);
c002acab:	83 ec 08             	sub    $0x8,%esp
c002acae:	50                   	push   %eax
c002acaf:	68 60 fa 02 c0       	push   $0xc002fa60
c002acb4:	e8 d3 e6 ff ff       	call   c002938c <fail>
c002acb9:	83 c4 10             	add    $0x10,%esp
c002acbc:	e9 74 ff ff ff       	jmp    c002ac35 <test_mlfqs_load_1+0xe0>
    fail ("load average fell below 0");
c002acc1:	83 ec 0c             	sub    $0xc,%esp
c002acc4:	68 6c f9 02 c0       	push   $0xc002f96c
c002acc9:	e8 be e6 ff ff       	call   c002938c <fail>
c002acce:	83 c4 10             	add    $0x10,%esp
c002acd1:	eb 99                	jmp    c002ac6c <test_mlfqs_load_1+0x117>
    fail ("load average stayed above 0.5 for more than 10 seconds");
c002acd3:	83 ec 0c             	sub    $0xc,%esp
c002acd6:	68 f0 fa 02 c0       	push   $0xc002faf0
c002acdb:	e8 ac e6 ff ff       	call   c002938c <fail>
c002ace0:	83 c4 10             	add    $0x10,%esp
c002ace3:	eb 8c                	jmp    c002ac71 <test_mlfqs_load_1+0x11c>

c002ace5 <load_thread>:
    }
}

static void
load_thread (void *aux UNUSED) 
{
c002ace5:	53                   	push   %ebx
c002ace6:	83 ec 14             	sub    $0x14,%esp
  int64_t sleep_time = 10 * TIMER_FREQ;
  int64_t spin_time = sleep_time + 60 * TIMER_FREQ;
  int64_t exit_time = spin_time + 60 * TIMER_FREQ;

  thread_set_nice (20);
c002ace9:	6a 14                	push   $0x14
c002aceb:	e8 45 60 ff ff       	call   c0020d35 <thread_set_nice>
  timer_sleep (sleep_time - timer_elapsed (start_time));
c002acf0:	83 c4 08             	add    $0x8,%esp
c002acf3:	ff 35 dc 84 03 c0    	pushl  0xc00384dc
c002acf9:	ff 35 d8 84 03 c0    	pushl  0xc00384d8
c002acff:	e8 84 87 ff ff       	call   c0023488 <timer_elapsed>
c002ad04:	83 c4 08             	add    $0x8,%esp
c002ad07:	b9 e8 03 00 00       	mov    $0x3e8,%ecx
c002ad0c:	bb 00 00 00 00       	mov    $0x0,%ebx
c002ad11:	29 c1                	sub    %eax,%ecx
c002ad13:	19 d3                	sbb    %edx,%ebx
c002ad15:	53                   	push   %ebx
c002ad16:	51                   	push   %ecx
c002ad17:	e8 88 87 ff ff       	call   c00234a4 <timer_sleep>
  while (timer_elapsed (start_time) < spin_time)
c002ad1c:	83 c4 10             	add    $0x10,%esp
c002ad1f:	83 ec 08             	sub    $0x8,%esp
c002ad22:	ff 35 dc 84 03 c0    	pushl  0xc00384dc
c002ad28:	ff 35 d8 84 03 c0    	pushl  0xc00384d8
c002ad2e:	e8 55 87 ff ff       	call   c0023488 <timer_elapsed>
c002ad33:	83 c4 10             	add    $0x10,%esp
c002ad36:	85 d2                	test   %edx,%edx
c002ad38:	78 e5                	js     c002ad1f <load_thread+0x3a>
c002ad3a:	85 d2                	test   %edx,%edx
c002ad3c:	7e 31                	jle    c002ad6f <load_thread+0x8a>
    continue;
  timer_sleep (exit_time - timer_elapsed (start_time));
c002ad3e:	83 ec 08             	sub    $0x8,%esp
c002ad41:	ff 35 dc 84 03 c0    	pushl  0xc00384dc
c002ad47:	ff 35 d8 84 03 c0    	pushl  0xc00384d8
c002ad4d:	e8 36 87 ff ff       	call   c0023488 <timer_elapsed>
c002ad52:	83 c4 08             	add    $0x8,%esp
c002ad55:	b9 c8 32 00 00       	mov    $0x32c8,%ecx
c002ad5a:	bb 00 00 00 00       	mov    $0x0,%ebx
c002ad5f:	29 c1                	sub    %eax,%ecx
c002ad61:	19 d3                	sbb    %edx,%ebx
c002ad63:	53                   	push   %ebx
c002ad64:	51                   	push   %ecx
c002ad65:	e8 3a 87 ff ff       	call   c00234a4 <timer_sleep>
}
c002ad6a:	83 c4 18             	add    $0x18,%esp
c002ad6d:	5b                   	pop    %ebx
c002ad6e:	c3                   	ret    
  while (timer_elapsed (start_time) < spin_time)
c002ad6f:	3d 57 1b 00 00       	cmp    $0x1b57,%eax
c002ad74:	76 a9                	jbe    c002ad1f <load_thread+0x3a>
c002ad76:	eb c6                	jmp    c002ad3e <load_thread+0x59>

c002ad78 <test_mlfqs_load_60>:
{
c002ad78:	55                   	push   %ebp
c002ad79:	57                   	push   %edi
c002ad7a:	56                   	push   %esi
c002ad7b:	53                   	push   %ebx
c002ad7c:	83 ec 2c             	sub    $0x2c,%esp
  ASSERT (thread_mlfqs);
c002ad7f:	80 3d ec 84 03 c0 00 	cmpb   $0x0,0xc00384ec
c002ad86:	0f 84 2c 01 00 00    	je     c002aeb8 <test_mlfqs_load_60+0x140>
  start_time = timer_ticks ();
c002ad8c:	e8 ce 86 ff ff       	call   c002345f <timer_ticks>
c002ad91:	a3 d8 84 03 c0       	mov    %eax,0xc00384d8
c002ad96:	89 15 dc 84 03 c0    	mov    %edx,0xc00384dc
  msg ("Starting %d niced load threads...", THREAD_CNT);
c002ad9c:	83 ec 08             	sub    $0x8,%esp
c002ad9f:	6a 3c                	push   $0x3c
c002ada1:	68 84 fb 02 c0       	push   $0xc002fb84
c002ada6:	e8 3d e5 ff ff       	call   c00292e8 <msg>
c002adab:	83 c4 10             	add    $0x10,%esp
  for (i = 0; i < THREAD_CNT; i++) 
c002adae:	bb 00 00 00 00       	mov    $0x0,%ebx
      snprintf(name, sizeof name, "load %d", i);
c002adb3:	8d 74 24 10          	lea    0x10(%esp),%esi
c002adb7:	53                   	push   %ebx
c002adb8:	68 56 fb 02 c0       	push   $0xc002fb56
c002adbd:	6a 10                	push   $0x10
c002adbf:	56                   	push   %esi
c002adc0:	e8 28 b7 ff ff       	call   c00264ed <snprintf>
      thread_create (name, PRI_DEFAULT, load_thread, NULL);
c002adc5:	6a 00                	push   $0x0
c002adc7:	68 e5 ac 02 c0       	push   $0xc002ace5
c002adcc:	6a 1f                	push   $0x1f
c002adce:	56                   	push   %esi
c002adcf:	e8 66 5c ff ff       	call   c0020a3a <thread_create>
  for (i = 0; i < THREAD_CNT; i++) 
c002add4:	43                   	inc    %ebx
c002add5:	83 c4 20             	add    $0x20,%esp
c002add8:	83 fb 3c             	cmp    $0x3c,%ebx
c002addb:	75 da                	jne    c002adb7 <test_mlfqs_load_60+0x3f>
       timer_elapsed (start_time) / TIMER_FREQ);
c002addd:	83 ec 08             	sub    $0x8,%esp
c002ade0:	ff 35 dc 84 03 c0    	pushl  0xc00384dc
c002ade6:	ff 35 d8 84 03 c0    	pushl  0xc00384d8
c002adec:	e8 97 86 ff ff       	call   c0023488 <timer_elapsed>
  msg ("Starting threads took %d seconds.",
c002adf1:	6a 00                	push   $0x0
c002adf3:	6a 64                	push   $0x64
c002adf5:	52                   	push   %edx
c002adf6:	50                   	push   %eax
c002adf7:	e8 2d c4 ff ff       	call   c0027229 <__divdi3>
c002adfc:	83 c4 1c             	add    $0x1c,%esp
c002adff:	52                   	push   %edx
c002ae00:	50                   	push   %eax
c002ae01:	68 a8 fb 02 c0       	push   $0xc002fba8
c002ae06:	e8 dd e4 ff ff       	call   c00292e8 <msg>
c002ae0b:	83 c4 10             	add    $0x10,%esp
c002ae0e:	bb 00 00 00 00       	mov    $0x0,%ebx
c002ae13:	be e8 03 00 00       	mov    $0x3e8,%esi
c002ae18:	bf 00 00 00 00       	mov    $0x0,%edi
      msg ("After %d seconds, load average=%d.%02d.",
c002ae1d:	bd 1f 85 eb 51       	mov    $0x51eb851f,%ebp
c002ae22:	89 5c 24 04          	mov    %ebx,0x4(%esp)
      int64_t sleep_until = start_time + TIMER_FREQ * (2 * i + 10);
c002ae26:	89 f0                	mov    %esi,%eax
c002ae28:	89 fa                	mov    %edi,%edx
c002ae2a:	03 05 d8 84 03 c0    	add    0xc00384d8,%eax
c002ae30:	13 15 dc 84 03 c0    	adc    0xc00384dc,%edx
c002ae36:	89 44 24 08          	mov    %eax,0x8(%esp)
c002ae3a:	89 54 24 0c          	mov    %edx,0xc(%esp)
      timer_sleep (sleep_until - timer_ticks ());
c002ae3e:	e8 1c 86 ff ff       	call   c002345f <timer_ticks>
c002ae43:	83 ec 08             	sub    $0x8,%esp
c002ae46:	8b 4c 24 10          	mov    0x10(%esp),%ecx
c002ae4a:	8b 5c 24 14          	mov    0x14(%esp),%ebx
c002ae4e:	29 c1                	sub    %eax,%ecx
c002ae50:	19 d3                	sbb    %edx,%ebx
c002ae52:	53                   	push   %ebx
c002ae53:	51                   	push   %ecx
c002ae54:	e8 4b 86 ff ff       	call   c00234a4 <timer_sleep>
      load_avg = thread_get_load_avg ();
c002ae59:	e8 de 5e ff ff       	call   c0020d3c <thread_get_load_avg>
c002ae5e:	89 c1                	mov    %eax,%ecx
      msg ("After %d seconds, load average=%d.%02d.",
c002ae60:	f7 ed                	imul   %ebp
c002ae62:	89 d0                	mov    %edx,%eax
c002ae64:	c1 f8 05             	sar    $0x5,%eax
c002ae67:	89 ca                	mov    %ecx,%edx
c002ae69:	c1 fa 1f             	sar    $0x1f,%edx
c002ae6c:	29 d0                	sub    %edx,%eax
c002ae6e:	8d 14 80             	lea    (%eax,%eax,4),%edx
c002ae71:	8d 14 92             	lea    (%edx,%edx,4),%edx
c002ae74:	c1 e2 02             	shl    $0x2,%edx
c002ae77:	29 d1                	sub    %edx,%ecx
c002ae79:	51                   	push   %ecx
c002ae7a:	50                   	push   %eax
c002ae7b:	8b 5c 24 1c          	mov    0x1c(%esp),%ebx
c002ae7f:	53                   	push   %ebx
c002ae80:	68 cc fb 02 c0       	push   $0xc002fbcc
c002ae85:	e8 5e e4 ff ff       	call   c00292e8 <msg>
c002ae8a:	81 c6 c8 00 00 00    	add    $0xc8,%esi
c002ae90:	83 d7 00             	adc    $0x0,%edi
c002ae93:	89 d8                	mov    %ebx,%eax
c002ae95:	83 c0 02             	add    $0x2,%eax
c002ae98:	89 44 24 24          	mov    %eax,0x24(%esp)
  for (i = 0; i < 90; i++) 
c002ae9c:	83 c4 20             	add    $0x20,%esp
c002ae9f:	89 f0                	mov    %esi,%eax
c002aea1:	35 38 4a 00 00       	xor    $0x4a38,%eax
c002aea6:	89 fa                	mov    %edi,%edx
c002aea8:	09 c2                	or     %eax,%edx
c002aeaa:	0f 85 76 ff ff ff    	jne    c002ae26 <test_mlfqs_load_60+0xae>
}
c002aeb0:	83 c4 2c             	add    $0x2c,%esp
c002aeb3:	5b                   	pop    %ebx
c002aeb4:	5e                   	pop    %esi
c002aeb5:	5f                   	pop    %edi
c002aeb6:	5d                   	pop    %ebp
c002aeb7:	c3                   	ret    
  ASSERT (thread_mlfqs);
c002aeb8:	83 ec 0c             	sub    $0xc,%esp
c002aebb:	68 99 ec 02 c0       	push   $0xc002ec99
c002aec0:	68 9f cd 02 c0       	push   $0xc002cd9f
c002aec5:	68 d4 cc 02 c0       	push   $0xc002ccd4
c002aeca:	6a 77                	push   $0x77
c002aecc:	68 60 fb 02 c0       	push   $0xc002fb60
c002aed1:	e8 39 c9 ff ff       	call   c002780f <debug_panic>

c002aed6 <load_thread>:
    }
}

static void
load_thread (void *seq_no_) 
{
c002aed6:	57                   	push   %edi
c002aed7:	56                   	push   %esi
c002aed8:	53                   	push   %ebx
c002aed9:	8b 44 24 10          	mov    0x10(%esp),%eax
  int seq_no = (int) seq_no_;
  int sleep_time = TIMER_FREQ * (10 + seq_no);
c002aedd:	8d 44 80 32          	lea    0x32(%eax,%eax,4),%eax
c002aee1:	8d 34 80             	lea    (%eax,%eax,4),%esi
c002aee4:	c1 e6 02             	shl    $0x2,%esi
  int spin_time = sleep_time + TIMER_FREQ * THREAD_CNT;
c002aee7:	8d 9e 70 17 00 00    	lea    0x1770(%esi),%ebx
  int exit_time = TIMER_FREQ * (THREAD_CNT * 2);

  timer_sleep (sleep_time - timer_elapsed (start_time));
c002aeed:	83 ec 08             	sub    $0x8,%esp
c002aef0:	ff 35 e4 84 03 c0    	pushl  0xc00384e4
c002aef6:	ff 35 e0 84 03 c0    	pushl  0xc00384e0
c002aefc:	e8 87 85 ff ff       	call   c0023488 <timer_elapsed>
c002af01:	83 c4 08             	add    $0x8,%esp
c002af04:	89 f7                	mov    %esi,%edi
c002af06:	c1 ff 1f             	sar    $0x1f,%edi
c002af09:	29 c6                	sub    %eax,%esi
c002af0b:	19 d7                	sbb    %edx,%edi
c002af0d:	57                   	push   %edi
c002af0e:	56                   	push   %esi
c002af0f:	e8 90 85 ff ff       	call   c00234a4 <timer_sleep>
  while (timer_elapsed (start_time) < spin_time)
c002af14:	83 c4 10             	add    $0x10,%esp
c002af17:	89 df                	mov    %ebx,%edi
c002af19:	c1 ff 1f             	sar    $0x1f,%edi
c002af1c:	83 ec 08             	sub    $0x8,%esp
c002af1f:	ff 35 e4 84 03 c0    	pushl  0xc00384e4
c002af25:	ff 35 e0 84 03 c0    	pushl  0xc00384e0
c002af2b:	e8 58 85 ff ff       	call   c0023488 <timer_elapsed>
c002af30:	83 c4 10             	add    $0x10,%esp
c002af33:	39 fa                	cmp    %edi,%edx
c002af35:	7c e5                	jl     c002af1c <load_thread+0x46>
c002af37:	7f 04                	jg     c002af3d <load_thread+0x67>
c002af39:	39 d8                	cmp    %ebx,%eax
c002af3b:	72 df                	jb     c002af1c <load_thread+0x46>
    continue;
  timer_sleep (exit_time - timer_elapsed (start_time));
c002af3d:	83 ec 08             	sub    $0x8,%esp
c002af40:	ff 35 e4 84 03 c0    	pushl  0xc00384e4
c002af46:	ff 35 e0 84 03 c0    	pushl  0xc00384e0
c002af4c:	e8 37 85 ff ff       	call   c0023488 <timer_elapsed>
c002af51:	83 c4 08             	add    $0x8,%esp
c002af54:	b9 e0 2e 00 00       	mov    $0x2ee0,%ecx
c002af59:	bb 00 00 00 00       	mov    $0x0,%ebx
c002af5e:	29 c1                	sub    %eax,%ecx
c002af60:	19 d3                	sbb    %edx,%ebx
c002af62:	53                   	push   %ebx
c002af63:	51                   	push   %ecx
c002af64:	e8 3b 85 ff ff       	call   c00234a4 <timer_sleep>
}
c002af69:	83 c4 10             	add    $0x10,%esp
c002af6c:	5b                   	pop    %ebx
c002af6d:	5e                   	pop    %esi
c002af6e:	5f                   	pop    %edi
c002af6f:	c3                   	ret    

c002af70 <test_mlfqs_load_avg>:
{
c002af70:	55                   	push   %ebp
c002af71:	57                   	push   %edi
c002af72:	56                   	push   %esi
c002af73:	53                   	push   %ebx
c002af74:	83 ec 2c             	sub    $0x2c,%esp
  ASSERT (thread_mlfqs);
c002af77:	80 3d ec 84 03 c0 00 	cmpb   $0x0,0xc00384ec
c002af7e:	0f 84 37 01 00 00    	je     c002b0bb <test_mlfqs_load_avg+0x14b>
  start_time = timer_ticks ();
c002af84:	e8 d6 84 ff ff       	call   c002345f <timer_ticks>
c002af89:	a3 e0 84 03 c0       	mov    %eax,0xc00384e0
c002af8e:	89 15 e4 84 03 c0    	mov    %edx,0xc00384e4
  msg ("Starting %d load threads...", THREAD_CNT);
c002af94:	83 ec 08             	sub    $0x8,%esp
c002af97:	6a 3c                	push   $0x3c
c002af99:	68 f4 fb 02 c0       	push   $0xc002fbf4
c002af9e:	e8 45 e3 ff ff       	call   c00292e8 <msg>
c002afa3:	83 c4 10             	add    $0x10,%esp
  for (i = 0; i < THREAD_CNT; i++) 
c002afa6:	bb 00 00 00 00       	mov    $0x0,%ebx
      snprintf(name, sizeof name, "load %d", i);
c002afab:	8d 74 24 10          	lea    0x10(%esp),%esi
c002afaf:	53                   	push   %ebx
c002afb0:	68 56 fb 02 c0       	push   $0xc002fb56
c002afb5:	6a 10                	push   $0x10
c002afb7:	56                   	push   %esi
c002afb8:	e8 30 b5 ff ff       	call   c00264ed <snprintf>
      thread_create (name, PRI_DEFAULT, load_thread, (void *) i);
c002afbd:	53                   	push   %ebx
c002afbe:	68 d6 ae 02 c0       	push   $0xc002aed6
c002afc3:	6a 1f                	push   $0x1f
c002afc5:	56                   	push   %esi
c002afc6:	e8 6f 5a ff ff       	call   c0020a3a <thread_create>
  for (i = 0; i < THREAD_CNT; i++) 
c002afcb:	43                   	inc    %ebx
c002afcc:	83 c4 20             	add    $0x20,%esp
c002afcf:	83 fb 3c             	cmp    $0x3c,%ebx
c002afd2:	75 db                	jne    c002afaf <test_mlfqs_load_avg+0x3f>
       timer_elapsed (start_time) / TIMER_FREQ);
c002afd4:	83 ec 08             	sub    $0x8,%esp
c002afd7:	ff 35 e4 84 03 c0    	pushl  0xc00384e4
c002afdd:	ff 35 e0 84 03 c0    	pushl  0xc00384e0
c002afe3:	e8 a0 84 ff ff       	call   c0023488 <timer_elapsed>
  msg ("Starting threads took %d seconds.",
c002afe8:	6a 00                	push   $0x0
c002afea:	6a 64                	push   $0x64
c002afec:	52                   	push   %edx
c002afed:	50                   	push   %eax
c002afee:	e8 36 c2 ff ff       	call   c0027229 <__divdi3>
c002aff3:	83 c4 1c             	add    $0x1c,%esp
c002aff6:	52                   	push   %edx
c002aff7:	50                   	push   %eax
c002aff8:	68 a8 fb 02 c0       	push   $0xc002fba8
c002affd:	e8 e6 e2 ff ff       	call   c00292e8 <msg>
  thread_set_nice (-20);
c002b002:	c7 04 24 ec ff ff ff 	movl   $0xffffffec,(%esp)
c002b009:	e8 27 5d ff ff       	call   c0020d35 <thread_set_nice>
c002b00e:	83 c4 10             	add    $0x10,%esp
c002b011:	bb 00 00 00 00       	mov    $0x0,%ebx
c002b016:	be e8 03 00 00       	mov    $0x3e8,%esi
c002b01b:	bf 00 00 00 00       	mov    $0x0,%edi
      msg ("After %d seconds, load average=%d.%02d.",
c002b020:	bd 1f 85 eb 51       	mov    $0x51eb851f,%ebp
c002b025:	89 5c 24 04          	mov    %ebx,0x4(%esp)
      int64_t sleep_until = start_time + TIMER_FREQ * (2 * i + 10);
c002b029:	89 f0                	mov    %esi,%eax
c002b02b:	89 fa                	mov    %edi,%edx
c002b02d:	03 05 e0 84 03 c0    	add    0xc00384e0,%eax
c002b033:	13 15 e4 84 03 c0    	adc    0xc00384e4,%edx
c002b039:	89 44 24 08          	mov    %eax,0x8(%esp)
c002b03d:	89 54 24 0c          	mov    %edx,0xc(%esp)
      timer_sleep (sleep_until - timer_ticks ());
c002b041:	e8 19 84 ff ff       	call   c002345f <timer_ticks>
c002b046:	83 ec 08             	sub    $0x8,%esp
c002b049:	8b 4c 24 10          	mov    0x10(%esp),%ecx
c002b04d:	8b 5c 24 14          	mov    0x14(%esp),%ebx
c002b051:	29 c1                	sub    %eax,%ecx
c002b053:	19 d3                	sbb    %edx,%ebx
c002b055:	53                   	push   %ebx
c002b056:	51                   	push   %ecx
c002b057:	e8 48 84 ff ff       	call   c00234a4 <timer_sleep>
      load_avg = thread_get_load_avg ();
c002b05c:	e8 db 5c ff ff       	call   c0020d3c <thread_get_load_avg>
c002b061:	89 c1                	mov    %eax,%ecx
      msg ("After %d seconds, load average=%d.%02d.",
c002b063:	f7 ed                	imul   %ebp
c002b065:	89 d0                	mov    %edx,%eax
c002b067:	c1 f8 05             	sar    $0x5,%eax
c002b06a:	89 ca                	mov    %ecx,%edx
c002b06c:	c1 fa 1f             	sar    $0x1f,%edx
c002b06f:	29 d0                	sub    %edx,%eax
c002b071:	8d 14 80             	lea    (%eax,%eax,4),%edx
c002b074:	8d 14 92             	lea    (%edx,%edx,4),%edx
c002b077:	c1 e2 02             	shl    $0x2,%edx
c002b07a:	29 d1                	sub    %edx,%ecx
c002b07c:	51                   	push   %ecx
c002b07d:	50                   	push   %eax
c002b07e:	8b 5c 24 1c          	mov    0x1c(%esp),%ebx
c002b082:	53                   	push   %ebx
c002b083:	68 cc fb 02 c0       	push   $0xc002fbcc
c002b088:	e8 5b e2 ff ff       	call   c00292e8 <msg>
c002b08d:	81 c6 c8 00 00 00    	add    $0xc8,%esi
c002b093:	83 d7 00             	adc    $0x0,%edi
c002b096:	89 d8                	mov    %ebx,%eax
c002b098:	83 c0 02             	add    $0x2,%eax
c002b09b:	89 44 24 24          	mov    %eax,0x24(%esp)
  for (i = 0; i < 90; i++) 
c002b09f:	83 c4 20             	add    $0x20,%esp
c002b0a2:	89 f0                	mov    %esi,%eax
c002b0a4:	35 38 4a 00 00       	xor    $0x4a38,%eax
c002b0a9:	89 fa                	mov    %edi,%edx
c002b0ab:	09 c2                	or     %eax,%edx
c002b0ad:	0f 85 76 ff ff ff    	jne    c002b029 <test_mlfqs_load_avg+0xb9>
}
c002b0b3:	83 c4 2c             	add    $0x2c,%esp
c002b0b6:	5b                   	pop    %ebx
c002b0b7:	5e                   	pop    %esi
c002b0b8:	5f                   	pop    %edi
c002b0b9:	5d                   	pop    %ebp
c002b0ba:	c3                   	ret    
  ASSERT (thread_mlfqs);
c002b0bb:	83 ec 0c             	sub    $0xc,%esp
c002b0be:	68 99 ec 02 c0       	push   $0xc002ec99
c002b0c3:	68 9f cd 02 c0       	push   $0xc002cd9f
c002b0c8:	68 e8 cc 02 c0       	push   $0xc002cce8
c002b0cd:	68 82 00 00 00       	push   $0x82
c002b0d2:	68 10 fc 02 c0       	push   $0xc002fc10
c002b0d7:	e8 33 c7 ff ff       	call   c002780f <debug_panic>

c002b0dc <test_mlfqs_recent_1>:
/* Sensitive to assumption that recent_cpu updates happen exactly
   when timer_ticks() % TIMER_FREQ == 0. */

void
test_mlfqs_recent_1 (void) 
{
c002b0dc:	55                   	push   %ebp
c002b0dd:	57                   	push   %edi
c002b0de:	56                   	push   %esi
c002b0df:	53                   	push   %ebx
c002b0e0:	83 ec 1c             	sub    $0x1c,%esp
  int64_t start_time;
  int last_elapsed = 0;
  
  ASSERT (thread_mlfqs);
c002b0e3:	80 3d ec 84 03 c0 00 	cmpb   $0x0,0xc00384ec
c002b0ea:	74 5c                	je     c002b148 <test_mlfqs_recent_1+0x6c>

  do 
    {
      msg ("Sleeping 10 seconds to allow recent_cpu to decay, please wait...");
c002b0ec:	83 ec 0c             	sub    $0xc,%esp
c002b0ef:	68 60 fc 02 c0       	push   $0xc002fc60
c002b0f4:	e8 ef e1 ff ff       	call   c00292e8 <msg>
      start_time = timer_ticks ();
c002b0f9:	e8 61 83 ff ff       	call   c002345f <timer_ticks>
c002b0fe:	89 c6                	mov    %eax,%esi
c002b100:	89 d7                	mov    %edx,%edi
      timer_sleep (DIV_ROUND_UP (start_time, TIMER_FREQ) - start_time
c002b102:	83 c0 63             	add    $0x63,%eax
c002b105:	83 d2 00             	adc    $0x0,%edx
c002b108:	6a 00                	push   $0x0
c002b10a:	6a 64                	push   $0x64
c002b10c:	52                   	push   %edx
c002b10d:	50                   	push   %eax
c002b10e:	e8 16 c1 ff ff       	call   c0027229 <__divdi3>
c002b113:	83 c4 18             	add    $0x18,%esp
c002b116:	29 f0                	sub    %esi,%eax
c002b118:	19 fa                	sbb    %edi,%edx
c002b11a:	05 e8 03 00 00       	add    $0x3e8,%eax
c002b11f:	83 d2 00             	adc    $0x0,%edx
c002b122:	52                   	push   %edx
c002b123:	50                   	push   %eax
c002b124:	e8 7b 83 ff ff       	call   c00234a4 <timer_sleep>
                   + 10 * TIMER_FREQ);
    }
  while (thread_get_recent_cpu () > 700);
c002b129:	e8 14 5c ff ff       	call   c0020d42 <thread_get_recent_cpu>
c002b12e:	83 c4 10             	add    $0x10,%esp
c002b131:	3d bc 02 00 00       	cmp    $0x2bc,%eax
c002b136:	7f b4                	jg     c002b0ec <test_mlfqs_recent_1+0x10>

  start_time = timer_ticks ();
c002b138:	e8 22 83 ff ff       	call   c002345f <timer_ticks>
c002b13d:	89 c6                	mov    %eax,%esi
c002b13f:	89 d7                	mov    %edx,%edi
  int last_elapsed = 0;
c002b141:	bd 00 00 00 00       	mov    $0x0,%ebp
c002b146:	eb 20                	jmp    c002b168 <test_mlfqs_recent_1+0x8c>
  ASSERT (thread_mlfqs);
c002b148:	83 ec 0c             	sub    $0xc,%esp
c002b14b:	68 99 ec 02 c0       	push   $0xc002ec99
c002b150:	68 9f cd 02 c0       	push   $0xc002cd9f
c002b155:	68 fc cc 02 c0       	push   $0xc002ccfc
c002b15a:	6a 73                	push   $0x73
c002b15c:	68 38 fc 02 c0       	push   $0xc002fc38
c002b161:	e8 a9 c6 ff ff       	call   c002780f <debug_panic>
{
c002b166:	89 dd                	mov    %ebx,%ebp
  for (;;) 
    {
      int elapsed = timer_elapsed (start_time);
c002b168:	83 ec 08             	sub    $0x8,%esp
c002b16b:	57                   	push   %edi
c002b16c:	56                   	push   %esi
c002b16d:	e8 16 83 ff ff       	call   c0023488 <timer_elapsed>
c002b172:	89 c3                	mov    %eax,%ebx
      if (elapsed % (TIMER_FREQ * 2) == 0 && elapsed > last_elapsed) 
c002b174:	b9 c8 00 00 00       	mov    $0xc8,%ecx
c002b179:	99                   	cltd   
c002b17a:	f7 f9                	idiv   %ecx
c002b17c:	83 c4 10             	add    $0x10,%esp
c002b17f:	85 d2                	test   %edx,%edx
c002b181:	75 e3                	jne    c002b166 <test_mlfqs_recent_1+0x8a>
c002b183:	39 dd                	cmp    %ebx,%ebp
c002b185:	7d df                	jge    c002b166 <test_mlfqs_recent_1+0x8a>
        {
          int recent_cpu = thread_get_recent_cpu ();
c002b187:	e8 b6 5b ff ff       	call   c0020d42 <thread_get_recent_cpu>
c002b18c:	89 44 24 0c          	mov    %eax,0xc(%esp)
          int load_avg = thread_get_load_avg ();
c002b190:	e8 a7 5b ff ff       	call   c0020d3c <thread_get_load_avg>
c002b195:	89 c1                	mov    %eax,%ecx
          int elapsed_seconds = elapsed / TIMER_FREQ;
c002b197:	b8 1f 85 eb 51       	mov    $0x51eb851f,%eax
c002b19c:	f7 eb                	imul   %ebx
c002b19e:	89 d5                	mov    %edx,%ebp
c002b1a0:	c1 fd 05             	sar    $0x5,%ebp
c002b1a3:	89 d8                	mov    %ebx,%eax
c002b1a5:	c1 f8 1f             	sar    $0x1f,%eax
c002b1a8:	29 c5                	sub    %eax,%ebp
          msg ("After %d seconds, recent_cpu is %d.%02d, load_avg is %d.%02d.",
c002b1aa:	83 ec 08             	sub    $0x8,%esp
c002b1ad:	b8 1f 85 eb 51       	mov    $0x51eb851f,%eax
c002b1b2:	f7 e9                	imul   %ecx
c002b1b4:	89 d0                	mov    %edx,%eax
c002b1b6:	c1 f8 05             	sar    $0x5,%eax
c002b1b9:	89 ca                	mov    %ecx,%edx
c002b1bb:	c1 fa 1f             	sar    $0x1f,%edx
c002b1be:	29 d0                	sub    %edx,%eax
c002b1c0:	8d 14 80             	lea    (%eax,%eax,4),%edx
c002b1c3:	8d 14 92             	lea    (%edx,%edx,4),%edx
c002b1c6:	c1 e2 02             	shl    $0x2,%edx
c002b1c9:	29 d1                	sub    %edx,%ecx
c002b1cb:	51                   	push   %ecx
c002b1cc:	50                   	push   %eax
c002b1cd:	b8 1f 85 eb 51       	mov    $0x51eb851f,%eax
c002b1d2:	8b 4c 24 1c          	mov    0x1c(%esp),%ecx
c002b1d6:	f7 e9                	imul   %ecx
c002b1d8:	89 d0                	mov    %edx,%eax
c002b1da:	c1 f8 05             	sar    $0x5,%eax
c002b1dd:	89 ca                	mov    %ecx,%edx
c002b1df:	c1 fa 1f             	sar    $0x1f,%edx
c002b1e2:	29 d0                	sub    %edx,%eax
c002b1e4:	8d 14 80             	lea    (%eax,%eax,4),%edx
c002b1e7:	8d 14 92             	lea    (%edx,%edx,4),%edx
c002b1ea:	c1 e2 02             	shl    $0x2,%edx
c002b1ed:	29 d1                	sub    %edx,%ecx
c002b1ef:	51                   	push   %ecx
c002b1f0:	50                   	push   %eax
c002b1f1:	55                   	push   %ebp
c002b1f2:	68 a4 fc 02 c0       	push   $0xc002fca4
c002b1f7:	e8 ec e0 ff ff       	call   c00292e8 <msg>
               elapsed_seconds,
               recent_cpu / 100, recent_cpu % 100,
               load_avg / 100, load_avg % 100);
          if (elapsed_seconds >= 180)
c002b1fc:	83 c4 20             	add    $0x20,%esp
c002b1ff:	81 fd b3 00 00 00    	cmp    $0xb3,%ebp
c002b205:	0f 8e 5b ff ff ff    	jle    c002b166 <test_mlfqs_recent_1+0x8a>
            break;
        } 
      last_elapsed = elapsed;
    }
}
c002b20b:	83 c4 1c             	add    $0x1c,%esp
c002b20e:	5b                   	pop    %ebx
c002b20f:	5e                   	pop    %esi
c002b210:	5f                   	pop    %edi
c002b211:	5d                   	pop    %ebp
c002b212:	c3                   	ret    

c002b213 <test_mlfqs_fair>:

static void load_thread (void *aux);

static void
test_mlfqs_fair (int thread_cnt, int nice_min, int nice_step)
{
c002b213:	55                   	push   %ebp
c002b214:	57                   	push   %edi
c002b215:	56                   	push   %esi
c002b216:	53                   	push   %ebx
c002b217:	81 ec 6c 01 00 00    	sub    $0x16c,%esp
c002b21d:	89 44 24 08          	mov    %eax,0x8(%esp)
c002b221:	89 54 24 04          	mov    %edx,0x4(%esp)
c002b225:	89 4c 24 0c          	mov    %ecx,0xc(%esp)
  struct thread_info info[MAX_THREAD_CNT];
  int64_t start_time;
  int nice;
  int i;

  ASSERT (thread_mlfqs);
c002b229:	80 3d ec 84 03 c0 00 	cmpb   $0x0,0xc00384ec
c002b230:	0f 84 23 01 00 00    	je     c002b359 <test_mlfqs_fair+0x146>
  ASSERT (thread_cnt <= MAX_THREAD_CNT);
c002b236:	83 7c 24 08 14       	cmpl   $0x14,0x8(%esp)
c002b23b:	0f 8f 36 01 00 00    	jg     c002b377 <test_mlfqs_fair+0x164>
  ASSERT (nice_min >= -10);
c002b241:	83 7c 24 04 f6       	cmpl   $0xfffffff6,0x4(%esp)
c002b246:	0f 8c 49 01 00 00    	jl     c002b395 <test_mlfqs_fair+0x182>
  ASSERT (nice_step >= 0);
c002b24c:	83 7c 24 0c 00       	cmpl   $0x0,0xc(%esp)
c002b251:	0f 88 5c 01 00 00    	js     c002b3b3 <test_mlfqs_fair+0x1a0>
  ASSERT (nice_min + nice_step * (thread_cnt - 1) <= 20);
c002b257:	8b 44 24 08          	mov    0x8(%esp),%eax
c002b25b:	48                   	dec    %eax
c002b25c:	0f af 44 24 0c       	imul   0xc(%esp),%eax
c002b261:	03 44 24 04          	add    0x4(%esp),%eax
c002b265:	83 f8 14             	cmp    $0x14,%eax
c002b268:	0f 8f 63 01 00 00    	jg     c002b3d1 <test_mlfqs_fair+0x1be>

  thread_set_nice (-20);
c002b26e:	83 ec 0c             	sub    $0xc,%esp
c002b271:	6a ec                	push   $0xffffffec
c002b273:	e8 bd 5a ff ff       	call   c0020d35 <thread_set_nice>

  start_time = timer_ticks ();
c002b278:	e8 e2 81 ff ff       	call   c002345f <timer_ticks>
c002b27d:	89 c6                	mov    %eax,%esi
c002b27f:	89 d7                	mov    %edx,%edi
  msg ("Starting %d threads...", thread_cnt);
c002b281:	83 c4 08             	add    $0x8,%esp
c002b284:	8b 5c 24 10          	mov    0x10(%esp),%ebx
c002b288:	53                   	push   %ebx
c002b289:	68 1e fd 02 c0       	push   $0xc002fd1e
c002b28e:	e8 55 e0 ff ff       	call   c00292e8 <msg>
  nice = nice_min;
  for (i = 0; i < thread_cnt; i++) 
c002b293:	83 c4 10             	add    $0x10,%esp
c002b296:	85 db                	test   %ebx,%ebx
c002b298:	0f 8e 51 01 00 00    	jle    c002b3ef <test_mlfqs_fair+0x1dc>
c002b29e:	8d 5c 24 20          	lea    0x20(%esp),%ebx
c002b2a2:	bd 00 00 00 00       	mov    $0x0,%ebp
    {
      struct thread_info *ti = &info[i];
      char name[16];

      ti->start_time = start_time;
c002b2a7:	89 33                	mov    %esi,(%ebx)
c002b2a9:	89 7b 04             	mov    %edi,0x4(%ebx)
      ti->tick_count = 0;
c002b2ac:	c7 43 08 00 00 00 00 	movl   $0x0,0x8(%ebx)
      ti->nice = nice;
c002b2b3:	8b 44 24 04          	mov    0x4(%esp),%eax
c002b2b7:	89 43 0c             	mov    %eax,0xc(%ebx)

      snprintf(name, sizeof name, "load %d", i);
c002b2ba:	55                   	push   %ebp
c002b2bb:	68 56 fb 02 c0       	push   $0xc002fb56
c002b2c0:	6a 10                	push   $0x10
c002b2c2:	8d 54 24 1c          	lea    0x1c(%esp),%edx
c002b2c6:	52                   	push   %edx
c002b2c7:	e8 21 b2 ff ff       	call   c00264ed <snprintf>
      thread_create (name, PRI_DEFAULT, load_thread, ti);
c002b2cc:	53                   	push   %ebx
c002b2cd:	68 2b b4 02 c0       	push   $0xc002b42b
c002b2d2:	6a 1f                	push   $0x1f
c002b2d4:	8d 4c 24 2c          	lea    0x2c(%esp),%ecx
c002b2d8:	51                   	push   %ecx
c002b2d9:	e8 5c 57 ff ff       	call   c0020a3a <thread_create>

      nice += nice_step;
c002b2de:	8b 54 24 2c          	mov    0x2c(%esp),%edx
c002b2e2:	01 54 24 24          	add    %edx,0x24(%esp)
  for (i = 0; i < thread_cnt; i++) 
c002b2e6:	45                   	inc    %ebp
c002b2e7:	83 c3 10             	add    $0x10,%ebx
c002b2ea:	83 c4 20             	add    $0x20,%esp
c002b2ed:	39 6c 24 08          	cmp    %ebp,0x8(%esp)
c002b2f1:	75 b4                	jne    c002b2a7 <test_mlfqs_fair+0x94>
    }
  msg ("Starting threads took %"PRId64" ticks.", timer_elapsed (start_time));
c002b2f3:	83 ec 08             	sub    $0x8,%esp
c002b2f6:	57                   	push   %edi
c002b2f7:	56                   	push   %esi
c002b2f8:	e8 8b 81 ff ff       	call   c0023488 <timer_elapsed>
c002b2fd:	83 c4 0c             	add    $0xc,%esp
c002b300:	52                   	push   %edx
c002b301:	50                   	push   %eax
c002b302:	68 a8 fd 02 c0       	push   $0xc002fda8
c002b307:	e8 dc df ff ff       	call   c00292e8 <msg>

  msg ("Sleeping 40 seconds to let threads run, please wait...");
c002b30c:	c7 04 24 cc fd 02 c0 	movl   $0xc002fdcc,(%esp)
c002b313:	e8 d0 df ff ff       	call   c00292e8 <msg>
  timer_sleep (40 * TIMER_FREQ);
c002b318:	83 c4 08             	add    $0x8,%esp
c002b31b:	6a 00                	push   $0x0
c002b31d:	68 a0 0f 00 00       	push   $0xfa0
c002b322:	e8 7d 81 ff ff       	call   c00234a4 <timer_sleep>
c002b327:	8d 74 24 38          	lea    0x38(%esp),%esi
c002b32b:	83 c4 10             	add    $0x10,%esp
c002b32e:	bb 00 00 00 00       	mov    $0x0,%ebx
  
  for (i = 0; i < thread_cnt; i++)
    msg ("Thread %d received %d ticks.", i, info[i].tick_count);
c002b333:	83 ec 04             	sub    $0x4,%esp
c002b336:	ff 36                	pushl  (%esi)
c002b338:	53                   	push   %ebx
c002b339:	68 35 fd 02 c0       	push   $0xc002fd35
c002b33e:	e8 a5 df ff ff       	call   c00292e8 <msg>
  for (i = 0; i < thread_cnt; i++)
c002b343:	43                   	inc    %ebx
c002b344:	83 c6 10             	add    $0x10,%esi
c002b347:	83 c4 10             	add    $0x10,%esp
c002b34a:	39 dd                	cmp    %ebx,%ebp
c002b34c:	75 e5                	jne    c002b333 <test_mlfqs_fair+0x120>
}
c002b34e:	81 c4 6c 01 00 00    	add    $0x16c,%esp
c002b354:	5b                   	pop    %ebx
c002b355:	5e                   	pop    %esi
c002b356:	5f                   	pop    %edi
c002b357:	5d                   	pop    %ebp
c002b358:	c3                   	ret    
  ASSERT (thread_mlfqs);
c002b359:	83 ec 0c             	sub    $0xc,%esp
c002b35c:	68 99 ec 02 c0       	push   $0xc002ec99
c002b361:	68 9f cd 02 c0       	push   $0xc002cd9f
c002b366:	68 10 cd 02 c0       	push   $0xc002cd10
c002b36b:	6a 49                	push   $0x49
c002b36d:	68 54 fd 02 c0       	push   $0xc002fd54
c002b372:	e8 98 c4 ff ff       	call   c002780f <debug_panic>
  ASSERT (thread_cnt <= MAX_THREAD_CNT);
c002b377:	83 ec 0c             	sub    $0xc,%esp
c002b37a:	68 e2 fc 02 c0       	push   $0xc002fce2
c002b37f:	68 9f cd 02 c0       	push   $0xc002cd9f
c002b384:	68 10 cd 02 c0       	push   $0xc002cd10
c002b389:	6a 4a                	push   $0x4a
c002b38b:	68 54 fd 02 c0       	push   $0xc002fd54
c002b390:	e8 7a c4 ff ff       	call   c002780f <debug_panic>
  ASSERT (nice_min >= -10);
c002b395:	83 ec 0c             	sub    $0xc,%esp
c002b398:	68 ff fc 02 c0       	push   $0xc002fcff
c002b39d:	68 9f cd 02 c0       	push   $0xc002cd9f
c002b3a2:	68 10 cd 02 c0       	push   $0xc002cd10
c002b3a7:	6a 4b                	push   $0x4b
c002b3a9:	68 54 fd 02 c0       	push   $0xc002fd54
c002b3ae:	e8 5c c4 ff ff       	call   c002780f <debug_panic>
  ASSERT (nice_step >= 0);
c002b3b3:	83 ec 0c             	sub    $0xc,%esp
c002b3b6:	68 0f fd 02 c0       	push   $0xc002fd0f
c002b3bb:	68 9f cd 02 c0       	push   $0xc002cd9f
c002b3c0:	68 10 cd 02 c0       	push   $0xc002cd10
c002b3c5:	6a 4c                	push   $0x4c
c002b3c7:	68 54 fd 02 c0       	push   $0xc002fd54
c002b3cc:	e8 3e c4 ff ff       	call   c002780f <debug_panic>
  ASSERT (nice_min + nice_step * (thread_cnt - 1) <= 20);
c002b3d1:	83 ec 0c             	sub    $0xc,%esp
c002b3d4:	68 78 fd 02 c0       	push   $0xc002fd78
c002b3d9:	68 9f cd 02 c0       	push   $0xc002cd9f
c002b3de:	68 10 cd 02 c0       	push   $0xc002cd10
c002b3e3:	6a 4d                	push   $0x4d
c002b3e5:	68 54 fd 02 c0       	push   $0xc002fd54
c002b3ea:	e8 20 c4 ff ff       	call   c002780f <debug_panic>
  msg ("Starting threads took %"PRId64" ticks.", timer_elapsed (start_time));
c002b3ef:	83 ec 08             	sub    $0x8,%esp
c002b3f2:	57                   	push   %edi
c002b3f3:	56                   	push   %esi
c002b3f4:	e8 8f 80 ff ff       	call   c0023488 <timer_elapsed>
c002b3f9:	83 c4 0c             	add    $0xc,%esp
c002b3fc:	52                   	push   %edx
c002b3fd:	50                   	push   %eax
c002b3fe:	68 a8 fd 02 c0       	push   $0xc002fda8
c002b403:	e8 e0 de ff ff       	call   c00292e8 <msg>
  msg ("Sleeping 40 seconds to let threads run, please wait...");
c002b408:	c7 04 24 cc fd 02 c0 	movl   $0xc002fdcc,(%esp)
c002b40f:	e8 d4 de ff ff       	call   c00292e8 <msg>
  timer_sleep (40 * TIMER_FREQ);
c002b414:	83 c4 08             	add    $0x8,%esp
c002b417:	6a 00                	push   $0x0
c002b419:	68 a0 0f 00 00       	push   $0xfa0
c002b41e:	e8 81 80 ff ff       	call   c00234a4 <timer_sleep>
c002b423:	83 c4 10             	add    $0x10,%esp
c002b426:	e9 23 ff ff ff       	jmp    c002b34e <test_mlfqs_fair+0x13b>

c002b42b <load_thread>:

static void
load_thread (void *ti_) 
{
c002b42b:	57                   	push   %edi
c002b42c:	56                   	push   %esi
c002b42d:	53                   	push   %ebx
c002b42e:	8b 7c 24 10          	mov    0x10(%esp),%edi
  struct thread_info *ti = ti_;
  int64_t sleep_time = 5 * TIMER_FREQ;
  int64_t spin_time = sleep_time + 30 * TIMER_FREQ;
  int64_t last_time = 0;

  thread_set_nice (ti->nice);
c002b432:	83 ec 0c             	sub    $0xc,%esp
c002b435:	ff 77 0c             	pushl  0xc(%edi)
c002b438:	e8 f8 58 ff ff       	call   c0020d35 <thread_set_nice>
  timer_sleep (sleep_time - timer_elapsed (ti->start_time));
c002b43d:	83 c4 08             	add    $0x8,%esp
c002b440:	ff 77 04             	pushl  0x4(%edi)
c002b443:	ff 37                	pushl  (%edi)
c002b445:	e8 3e 80 ff ff       	call   c0023488 <timer_elapsed>
c002b44a:	83 c4 08             	add    $0x8,%esp
c002b44d:	b9 f4 01 00 00       	mov    $0x1f4,%ecx
c002b452:	bb 00 00 00 00       	mov    $0x0,%ebx
c002b457:	29 c1                	sub    %eax,%ecx
c002b459:	19 d3                	sbb    %edx,%ebx
c002b45b:	53                   	push   %ebx
c002b45c:	51                   	push   %ecx
c002b45d:	e8 42 80 ff ff       	call   c00234a4 <timer_sleep>
  while (timer_elapsed (ti->start_time) < spin_time) 
c002b462:	83 c4 10             	add    $0x10,%esp
  int64_t last_time = 0;
c002b465:	be 00 00 00 00       	mov    $0x0,%esi
c002b46a:	bb 00 00 00 00       	mov    $0x0,%ebx
  while (timer_elapsed (ti->start_time) < spin_time) 
c002b46f:	eb 1b                	jmp    c002b48c <load_thread+0x61>
c002b471:	3d ab 0d 00 00       	cmp    $0xdab,%eax
c002b476:	77 2c                	ja     c002b4a4 <load_thread+0x79>
    {
      int64_t cur_time = timer_ticks ();
c002b478:	e8 e2 7f ff ff       	call   c002345f <timer_ticks>
      if (cur_time != last_time)
c002b47d:	31 c6                	xor    %eax,%esi
c002b47f:	31 d3                	xor    %edx,%ebx
c002b481:	09 f3                	or     %esi,%ebx
c002b483:	74 03                	je     c002b488 <load_thread+0x5d>
        ti->tick_count++;
c002b485:	ff 47 08             	incl   0x8(%edi)
{
c002b488:	89 c6                	mov    %eax,%esi
c002b48a:	89 d3                	mov    %edx,%ebx
  while (timer_elapsed (ti->start_time) < spin_time) 
c002b48c:	83 ec 08             	sub    $0x8,%esp
c002b48f:	ff 77 04             	pushl  0x4(%edi)
c002b492:	ff 37                	pushl  (%edi)
c002b494:	e8 ef 7f ff ff       	call   c0023488 <timer_elapsed>
c002b499:	83 c4 10             	add    $0x10,%esp
c002b49c:	85 d2                	test   %edx,%edx
c002b49e:	78 d8                	js     c002b478 <load_thread+0x4d>
c002b4a0:	85 d2                	test   %edx,%edx
c002b4a2:	7e cd                	jle    c002b471 <load_thread+0x46>
      last_time = cur_time;
    }
}
c002b4a4:	5b                   	pop    %ebx
c002b4a5:	5e                   	pop    %esi
c002b4a6:	5f                   	pop    %edi
c002b4a7:	c3                   	ret    

c002b4a8 <test_mlfqs_fair_2>:
{
c002b4a8:	83 ec 0c             	sub    $0xc,%esp
  test_mlfqs_fair (2, 0, 0);
c002b4ab:	b9 00 00 00 00       	mov    $0x0,%ecx
c002b4b0:	ba 00 00 00 00       	mov    $0x0,%edx
c002b4b5:	b8 02 00 00 00       	mov    $0x2,%eax
c002b4ba:	e8 54 fd ff ff       	call   c002b213 <test_mlfqs_fair>
}
c002b4bf:	83 c4 0c             	add    $0xc,%esp
c002b4c2:	c3                   	ret    

c002b4c3 <test_mlfqs_fair_20>:
{
c002b4c3:	83 ec 0c             	sub    $0xc,%esp
  test_mlfqs_fair (20, 0, 0);
c002b4c6:	b9 00 00 00 00       	mov    $0x0,%ecx
c002b4cb:	ba 00 00 00 00       	mov    $0x0,%edx
c002b4d0:	b8 14 00 00 00       	mov    $0x14,%eax
c002b4d5:	e8 39 fd ff ff       	call   c002b213 <test_mlfqs_fair>
}
c002b4da:	83 c4 0c             	add    $0xc,%esp
c002b4dd:	c3                   	ret    

c002b4de <test_mlfqs_nice_2>:
{
c002b4de:	83 ec 0c             	sub    $0xc,%esp
  test_mlfqs_fair (2, 0, 5);
c002b4e1:	b9 05 00 00 00       	mov    $0x5,%ecx
c002b4e6:	ba 00 00 00 00       	mov    $0x0,%edx
c002b4eb:	b8 02 00 00 00       	mov    $0x2,%eax
c002b4f0:	e8 1e fd ff ff       	call   c002b213 <test_mlfqs_fair>
}
c002b4f5:	83 c4 0c             	add    $0xc,%esp
c002b4f8:	c3                   	ret    

c002b4f9 <test_mlfqs_nice_10>:
{
c002b4f9:	83 ec 0c             	sub    $0xc,%esp
  test_mlfqs_fair (10, 0, 1);
c002b4fc:	b9 01 00 00 00       	mov    $0x1,%ecx
c002b501:	ba 00 00 00 00       	mov    $0x0,%edx
c002b506:	b8 0a 00 00 00       	mov    $0xa,%eax
c002b50b:	e8 03 fd ff ff       	call   c002b213 <test_mlfqs_fair>
}
c002b510:	83 c4 0c             	add    $0xc,%esp
c002b513:	c3                   	ret    

c002b514 <block_thread>:
  msg ("Block thread should have already acquired lock.");
}

static void
block_thread (void *lock_) 
{
c002b514:	57                   	push   %edi
c002b515:	56                   	push   %esi
c002b516:	83 ec 10             	sub    $0x10,%esp
  struct lock *lock = lock_;
  int64_t start_time;

  msg ("Block thread spinning for 20 seconds...");
c002b519:	68 04 fe 02 c0       	push   $0xc002fe04
c002b51e:	e8 c5 dd ff ff       	call   c00292e8 <msg>
  start_time = timer_ticks ();
c002b523:	e8 37 7f ff ff       	call   c002345f <timer_ticks>
c002b528:	89 c6                	mov    %eax,%esi
c002b52a:	89 d7                	mov    %edx,%edi
  while (timer_elapsed (start_time) < 20 * TIMER_FREQ)
c002b52c:	83 c4 10             	add    $0x10,%esp
c002b52f:	83 ec 08             	sub    $0x8,%esp
c002b532:	57                   	push   %edi
c002b533:	56                   	push   %esi
c002b534:	e8 4f 7f ff ff       	call   c0023488 <timer_elapsed>
c002b539:	83 c4 10             	add    $0x10,%esp
c002b53c:	85 d2                	test   %edx,%edx
c002b53e:	78 ef                	js     c002b52f <block_thread+0x1b>
c002b540:	85 d2                	test   %edx,%edx
c002b542:	7e 2b                	jle    c002b56f <block_thread+0x5b>
    continue;

  msg ("Block thread acquiring lock...");
c002b544:	83 ec 0c             	sub    $0xc,%esp
c002b547:	68 2c fe 02 c0       	push   $0xc002fe2c
c002b54c:	e8 97 dd ff ff       	call   c00292e8 <msg>
  lock_acquire (lock);
c002b551:	83 c4 04             	add    $0x4,%esp
c002b554:	ff 74 24 1c          	pushl  0x1c(%esp)
c002b558:	e8 da 6f ff ff       	call   c0022537 <lock_acquire>

  msg ("...got it.");
c002b55d:	c7 04 24 04 ff 02 c0 	movl   $0xc002ff04,(%esp)
c002b564:	e8 7f dd ff ff       	call   c00292e8 <msg>
}
c002b569:	83 c4 14             	add    $0x14,%esp
c002b56c:	5e                   	pop    %esi
c002b56d:	5f                   	pop    %edi
c002b56e:	c3                   	ret    
  while (timer_elapsed (start_time) < 20 * TIMER_FREQ)
c002b56f:	3d cf 07 00 00       	cmp    $0x7cf,%eax
c002b574:	76 b9                	jbe    c002b52f <block_thread+0x1b>
c002b576:	eb cc                	jmp    c002b544 <block_thread+0x30>

c002b578 <test_mlfqs_block>:
{
c002b578:	57                   	push   %edi
c002b579:	56                   	push   %esi
c002b57a:	53                   	push   %ebx
c002b57b:	83 ec 20             	sub    $0x20,%esp
  ASSERT (thread_mlfqs);
c002b57e:	80 3d ec 84 03 c0 00 	cmpb   $0x0,0xc00384ec
c002b585:	0f 84 a9 00 00 00    	je     c002b634 <test_mlfqs_block+0xbc>
  msg ("Main thread acquiring lock.");
c002b58b:	83 ec 0c             	sub    $0xc,%esp
c002b58e:	68 0f ff 02 c0       	push   $0xc002ff0f
c002b593:	e8 50 dd ff ff       	call   c00292e8 <msg>
  lock_init (&lock);
c002b598:	83 c4 04             	add    $0x4,%esp
c002b59b:	8d 5c 24 14          	lea    0x14(%esp),%ebx
c002b59f:	53                   	push   %ebx
c002b5a0:	e8 10 6f ff ff       	call   c00224b5 <lock_init>
  lock_acquire (&lock);
c002b5a5:	89 1c 24             	mov    %ebx,(%esp)
c002b5a8:	e8 8a 6f ff ff       	call   c0022537 <lock_acquire>
  msg ("Main thread creating block thread, sleeping 25 seconds...");
c002b5ad:	c7 04 24 70 fe 02 c0 	movl   $0xc002fe70,(%esp)
c002b5b4:	e8 2f dd ff ff       	call   c00292e8 <msg>
  thread_create ("block", PRI_DEFAULT, block_thread, &lock);
c002b5b9:	53                   	push   %ebx
c002b5ba:	68 14 b5 02 c0       	push   $0xc002b514
c002b5bf:	6a 1f                	push   $0x1f
c002b5c1:	68 92 ec 02 c0       	push   $0xc002ec92
c002b5c6:	e8 6f 54 ff ff       	call   c0020a3a <thread_create>
  timer_sleep (25 * TIMER_FREQ);
c002b5cb:	83 c4 18             	add    $0x18,%esp
c002b5ce:	6a 00                	push   $0x0
c002b5d0:	68 c4 09 00 00       	push   $0x9c4
c002b5d5:	e8 ca 7e ff ff       	call   c00234a4 <timer_sleep>
  msg ("Main thread spinning for 5 seconds...");
c002b5da:	c7 04 24 ac fe 02 c0 	movl   $0xc002feac,(%esp)
c002b5e1:	e8 02 dd ff ff       	call   c00292e8 <msg>
  start_time = timer_ticks ();
c002b5e6:	e8 74 7e ff ff       	call   c002345f <timer_ticks>
c002b5eb:	89 c6                	mov    %eax,%esi
c002b5ed:	89 d7                	mov    %edx,%edi
  while (timer_elapsed (start_time) < 5 * TIMER_FREQ)
c002b5ef:	83 c4 10             	add    $0x10,%esp
c002b5f2:	83 ec 08             	sub    $0x8,%esp
c002b5f5:	57                   	push   %edi
c002b5f6:	56                   	push   %esi
c002b5f7:	e8 8c 7e ff ff       	call   c0023488 <timer_elapsed>
c002b5fc:	83 c4 10             	add    $0x10,%esp
c002b5ff:	85 d2                	test   %edx,%edx
c002b601:	78 ef                	js     c002b5f2 <test_mlfqs_block+0x7a>
c002b603:	85 d2                	test   %edx,%edx
c002b605:	7e 4b                	jle    c002b652 <test_mlfqs_block+0xda>
  msg ("Main thread releasing lock.");
c002b607:	83 ec 0c             	sub    $0xc,%esp
c002b60a:	68 2b ff 02 c0       	push   $0xc002ff2b
c002b60f:	e8 d4 dc ff ff       	call   c00292e8 <msg>
  lock_release (&lock);
c002b614:	83 c4 04             	add    $0x4,%esp
c002b617:	8d 44 24 14          	lea    0x14(%esp),%eax
c002b61b:	50                   	push   %eax
c002b61c:	e8 3b 70 ff ff       	call   c002265c <lock_release>
  msg ("Block thread should have already acquired lock.");
c002b621:	c7 04 24 d4 fe 02 c0 	movl   $0xc002fed4,(%esp)
c002b628:	e8 bb dc ff ff       	call   c00292e8 <msg>
}
c002b62d:	83 c4 30             	add    $0x30,%esp
c002b630:	5b                   	pop    %ebx
c002b631:	5e                   	pop    %esi
c002b632:	5f                   	pop    %edi
c002b633:	c3                   	ret    
  ASSERT (thread_mlfqs);
c002b634:	83 ec 0c             	sub    $0xc,%esp
c002b637:	68 99 ec 02 c0       	push   $0xc002ec99
c002b63c:	68 9f cd 02 c0       	push   $0xc002cd9f
c002b641:	68 20 cd 02 c0       	push   $0xc002cd20
c002b646:	6a 1c                	push   $0x1c
c002b648:	68 4c fe 02 c0       	push   $0xc002fe4c
c002b64d:	e8 bd c1 ff ff       	call   c002780f <debug_panic>
  while (timer_elapsed (start_time) < 5 * TIMER_FREQ)
c002b652:	3d f3 01 00 00       	cmp    $0x1f3,%eax
c002b657:	76 99                	jbe    c002b5f2 <test_mlfqs_block+0x7a>
c002b659:	eb ac                	jmp    c002b607 <test_mlfqs_block+0x8f>
