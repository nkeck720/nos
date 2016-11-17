# What is NOS?
NOS is a simple operating system that is written in FASM syntax. It was created after learning real mode assembly back in 2014.

# Any system requirements?
NOS requires an Intel 80386 or better with at least one megabyte of RAM. The original intent was for this to run on an IBM AT, however the 80286 doesn't have some of the instructions that I need. These are, of course, minimum requirements.

# How do I compile this operating system?
For Windows, you have to compile each file by itself. It doesn't matter what order you compile them in, except image.asm should come LAST, after you have compiled every other source file. Then, optionally, you can rename image.bin to image.img. The resulting image is a 1.44MB floppy disk image.

In Unix/Linux/BSD, make sure you have fasm in your $PATH. Once you have done that, run compile.sh and image.img should be left behind in the compile directory. Optionally, the script will allow you to write the 1.44MB image to the floppy disk in /dev/fd0. THIS WRITING METHOD DOES NOT WORK WITH MOST USB FLOPPY DISK DRIVES. DO NOT USE THIS SCRIPT TO ATTEMPT TO WRITE TO USB FLOPPY DISK DRIVES.

# Questions?

If you have any questions, you can email me at noahkeck72@gmail.com. If you find bugs or wish to contribute, feel free to submit an issue at Github (nkeck720/nos) or create a pull request. I always accept any help I can get.
