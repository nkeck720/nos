# What is NOS?
NOS is a simple operating system that is written in FASM syntax. It was created after learning real mode assembly back in 2014.

# Any system requirements?
NOS requires an Intel 80386 or better with at least one megabyte of RAM. The original intent was for this to run on an IBM AT, however the 80286 doesn't have some of the instructions that I need. These are, of course, minimum requirements.

# How do I compile this operating system?
For Windows, you have to compile each file by itself. It doesn't matter what order you compile them in, except image.asm should come LAST, after you have compiled every other source file. Then, optionally, you can rename image.bin to image.img. The resulting image is a 1.44MB floppy disk image.

In Unix/Linux/BSD, make sure you have fasm in your $PATH. Once you have done that, run compile.sh and image.img should be left behind in the compile directory. Optionally, the script will allow you to write the 1.44MB image to the floppy disk in /dev/fd0. THIS WRITING METHOD DOES NOT WORK WITH MOST USB FLOPPY DISK DRIVES. DO NOT USE THIS SCRIPT TO ATTEMPT TO WRITE TO USB FLOPPY DISK DRIVES.

# Questions?

If you have any questions, you can email me at nos.suppt@gmail.com. If you find bugs or wish to contribute, feel free to submit an issue at Github (nkeck720/nos) or create a pull request. I always accept any help I can get.

# Legal agreement

This operating system is in late beta, and only minimal testing has been done at this point. It is unknown how some hardware will react to this software product. The developers of NOS and their subsidiaries are not liable for any hardware damage caused by this software product. If you have a complaint, please file an issue on our Github page (nkeck720/nos) or email us at nos.suppt@gmail.com. If your hardware does not meet the minimum system requirements, also posted on the Github page, do not attempt to use this operating system. It is unknown what effect it will have on your system. By using NOS, you are entering a legal agreement as described by the GNU GPL version 2, or at your choice any later version, as well as the terms of the legally binding agreement you are currently reading. Additionally, THIS SOFTWARE PRODUCT COMES WITH NO WARRANTY OF ANY KIND, EXPRESS OR IMPLIED. We cannot guarantee the ability of this product to work on every system, and while we strive to reach that goal, we are not liable if your particular hardware configuration does not work with NOS. We hope that NOS will be an enjoyable experience for you.
