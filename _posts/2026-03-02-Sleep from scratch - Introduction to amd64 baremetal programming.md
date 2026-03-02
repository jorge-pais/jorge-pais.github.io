---
layout: post
title: Sleep from scratch - Introduction to amd64 bare metal
date: 2026-03-02
tags: 
    - Programming
categories:
    - projects

permalink_name: /projects
---

Most programmers live a life of luxury. We call `printf()`, and text appears. We call `sleep()` and the process (which the operating system has already created for us) pauses. We take for granted the massive and almost invisible infrastructure that supports pretty much all applications. This is provided by the C standard library, via implementataions such as glibc and musl.

> If you wish to make an apple pie from scratch you must first invent the universe - Carl Sagan

We can start with a standard implementation of the sleep utility we can find in linux.

```c
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

int main(int argc, char** argv) {
    if(argc != 2){
        printf("Insufficient arguments, Usage: %s <SECONDS>\n", argv[0]);
        return 0;
    }
    unsigned int seconds = atoi(argv[1]);
    printf("Sleeping for %d seconds\n", seconds);
    sleep(seconds);
    return 0;
}
```

This compiles and works perfectly fine, until we use a single `-nostdlib` flag, in which case the compiler falls apart as it can no longer implicitly link with glibc. By breaking this dependency we can see that not only library functions such as printf and atoi have broken, but we no longer have a `_start` entry-point defined.

```bash
$ gcc test.c -nostdlib -o out
#/usr/bin/ld: warning: cannot find entry symbol _start; defaulting to 0000000000001040
#/usr/bin/ld: test.c: undefined reference to `printf'
#/usr/bin/ld: test.c: undefined reference to `atoi'
#/usr/bin/ld: test.c: undefined reference to `sleep'
#collect2: error: ld returned 1 exit status
```

## (\_start)ing our application

If you never heard of ABI, it stands for Application Binary Interface, and it is the definition for how applications interact with the operating system. For linux systems is the [System V ABI for amd64](https://gitlab.com/x86-psABIs/x86-64-ABI), this is platform dependent of course, and it the root of many different evils (see [C Isn't a Programming Language Anymore](https://faultlore.com/blah/c-isnt-a-language/)).

From the ABI it is specified that the application entry point is in `_start`. Linux will simply jump to this entry point, and at that moment the CPU registers and the stack are in a specific state:
1. `%rbp` - Is the frame pointer. ABI states that this should be zeroed out, as this tells debuggers and stack-tracers that this the root for our program.
2. `%rsp` - This is the stack pointer. It is pointing directly to the argument count
3. `%rsp + 8` - This is the stack pointer. It is pointing directly to the argument count

```c
__attribute__((naked)) void _start(){
    // When we call our program with arguments, rsp register has the argc 
    // and rsp + 8 has the argv pointer essentially.
    //
    // see system V abi for amd64

   __asm__ __volatile__(
        // the content for this register is unspecified at process initialization time, 
        // but the user code should make the deepest stack frame by setting the frame pointer to zero
        "xor %rbp, %rbp\n" 
        "mov (%rsp), %rdi\n" // move the argc, rdi is the first argument for the function call
        "lea 8(%rsp), %rsi\n" // move (load effective address) the argv, rsi is the second argument
        "and $-16, %rsp\n" // make sure that the stack pointer is aligned
        "call main\n"
    );
}

```

In the C calling convention for System V ABI ([see section  A.2](https://gitlab.com/x86-psABIs/x86-64-ABI)), the first argument goes in RDI and the second in RSI. As such we get `argc` from `%rsp` and move it to `%rdi`. We then load the effective address 8 bytes above the stack pointer into `%rsi`. The ABI also requires that the stack register is aligned to 16-bytes before a `call` instruction, we can do a trick where we and this register with `0xFFFFFFFFFFFFFFF0`. We then call main normally.

You can notice if you try to run this that it will compile, but if `main` returns, the CPU will simply try to execute whatever bytes come next in memory. In a normal program, the C library provides a framework to catch the return valuie of main and immediately trigger a system call to `exit`. We are also going to have to do this on our own.

## System calls

In my current daily work I have seen some misconceptions to what system calls really are. A recent project that I have worked on required launching a new process for interacting with system network configurations. For this we used `posix_spawn()` as this allows us to create a new child process that will execute a specified file from within our current execution context. I've unfortunately seen senior developers refer to this _Linux library_ function as a syscall. System calls are simply a way for user applications to requesst priviledged kernel services, such as file I/O, process creation or hardware access. For amd64, we have the syscall instruction which will change the CPU's privilege mode and switch to the kernel context which will execute the call. 

The system call instruction `syscall` has several definitions depending on the number of arguments that you mean to pass to it. For the syscalls that we implement, there is only a single return value. We also have to specify the system call number, which identifies the call that we want. 

The syntax for passing the arguments is kinda weird and esoteric, you can see the definition for this in the [operands for inline assembly in GCC](https://gcc.gnu.org/onlinedocs/gcc-15.2.0/gcc/Extended-Asm.html) . 

```c
long syscall3(long number, long arg1, long arg2, long arg3){
    long result;
    __asm__ __volatile__(
        "syscall"
        : "=a" (result) 
        : "a"(number), "D" (arg1), "S" (arg2), "d"(arg3)
        : "rcx", "r11", "memory" 
    );
    return result;
}
```

| **C Argument** | **Register** | **Constraint** |
| -------------- | ------------ | -------------- |
| `number`       | **RAX**      | `"a"`          |
| `arg1`         | **RDI**      | `"D"`          |
| `arg2`         | **RSI**      | `"S"`          |
| `arg3`         | **RDX**      | `"d"`          |

Notice the last line: `: "rcx", "r11", "memory"`. This is arguably the most important part for stability. When the `syscall` instruction executes, the Intel/AMD architecture specifies that the CPU destroys whatever was in the `RCX` and `R11` registers to store the return address and processor flags. Without this, your program might work 99% of the time but crash randomly when the compiler happens to use `RCX` for a loop counter.
## Writing to the console

Now that we have a way to trigger the syscall, we can finally do something visible on our program. We use `SYS_write` ([see a list of all linux syscalls here](https://filippo.io/linux-syscall-table/)) to send a string of bytes to stdout.

```c
#define SYS_write 1
#define stdout 1 // see stdout(3)

void print(char* str){
    syscall3(SYS_write, stdout, (long)str, strlen(str));
}

int main(int argc, char** argv){
    if(argc != 2){
        print("Insufficient number of arguments, Usage: ");
        print(argv[0]);
        print(" <SECONDS>\n");
        return 1;
    }
	
	print("Sleeping for ");
    print(argv[1]);
    print(" seconds...\n");

	return 0;	
}
```

## Sleeping

Taking a look at the linux syscalls we can find [SYS_nanosleep](https://linux.die.net/man/2/nanosleep). For calling it we actually have to pass a timespec struct, which is usually defined in `<time.h>`. Since it takes two arguments, we need to define the wrapper for syscall with 2 input args. We are just interested in using the duration parameter, and set the second pointer to zero.

```c
long syscall2(long number, long arg1, long arg2){
    long result;
    __asm__ __volatile__(
        "syscall"
        : "=a" (result) // output result of syscall, rax
        : "a"(number), "D" (arg1), "S" (arg2) // input operands: a is rax D is rdi; S is rsi
        // kernel clobbers (destroys) both rcx and r11 registers. 
        // Also memory, as in linux, any syscall can modify any memory in the program
        : "rcx", "r11", "memory" 
    );
    return result;
}

void sleep(long seconds) {
    struct timespec { 
        long tv_sec;
        long tv_nsec;
    } ts = {0};

    ts.tv_sec = seconds;

    syscall2(SYS_nanosleep, (long)(&ts), 0);
}
```

## (exit\_)ing

To shut down gracefully, we must explicitly tell the Linux kernel to terminate our process. On the AMD64 architecture, this is System Call ID 60. Unlike write or nanosleep, the exit syscall never returns. The kernel wipes the process from memory, closes its file descriptors, and notifies the parent process of the status code.

```c
long syscall(long number, long arg1){
    long result;
    __asm__ __volatile__(
        "syscall"
        : "=a" (result)
        : "a"(number), "D" (arg1)
        : "rcx", "r11", "memory" 
    );
    return result;
}

#define SYS_exit 60
void exit_(int exitCode){
    syscall(SYS_exit, (long)exitCode);
}

```

Now we can complete the `_start` method we defined before:

```c
__attribute__((naked)) void _start(){
   __asm__ __volatile__(
        // ... (stack setup and argc/argv logic we discussed) ...

        "call main\n"
        "mov %rax, %rdi\n"
        "call exit_"
    );
}
```

And now we are pretty much done! Checkout the complete code on [github gists](https://gist.github.com/jorge-pais/83ed91d0ff1915ee678646ffe2d83d5a). I added an atoi helper to parse the string. And have added the `void __stack_chk_fail(void)` function, as this was required on my personal arch linux install. On my work laptop running fedora 42 this didn´t raise any issues. You can compile with `-fno-stack-protector` in order to circumvent this.

## References

* [AMD64 assembly tutorial](https://github.com/0xAX/asm)
* [System-V ABI for amd64](https://gitlab.com/x86-psABIs/x86-64-ABI)
* [Operands for inline assembly in gcc](https://gcc.gnu.org/onlinedocs/gcc-15.2.0/gcc/Extended-Asm.html)
* [Machine constrains for inline assembly](https://gcc.gnu.org/onlinedocs/gcc/Machine-Constraints.html)
* [System call list for linux](https://filippo.io/linux-syscall-table/)

