# What is NOS?
NOS is a simple operating system that is written in FASM syntax. It was created after learning real mode assembly back in 2014.

# Any system requirements?
NOS requires an Intel 80386 or better with at least one megabyte of RAM, and at least one 1.44MB floppy disk drive. The original intent was for this to run on an IBM AT, however the 80286 doesn't have some of the instructions that I need. These are, of course, minimum requirements.

# How do I compile this operating system?
For Windows, you have to compile each file by itself. It doesn't matter what order you compile them in, except image.asm should come LAST, after you have compiled every other source file. Then, optionally, you can rename image.bin to image.img. The resulting image is a 1.44MB floppy disk image.

In Unix/Linux/BSD, make sure you have fasm in your $PATH. Once you have done that, run compile.sh and image.img should be left behind in the compile directory.

# Questions?

If you have any questions, you can email me at nos.suppt@gmail.com. Your email gets sent to a real person and not a bot, and so I will always be able to respond to your individual situation.

# Legal agreement

This operating system is in late beta, and only minimal testing has been done at this point. It is unknown how some hardware will react to this software product. The developer(s) of NOS and their subsidiaries are not liable for any hardware damage caused by this software product. If you have a complaint, please file an issue on our Github page (nkeck720/nos) or email us at nos.suppt@gmail.com. If your hardware does not meet the minimum system requirements, also posted on the Github page, do not attempt to use this operating system. It is unknown what effect it will have on your system. By using NOS, you are entering a legal agreement as described by the GNU GPL version 2, or at your choice any later version, as well as the terms of the legally binding agreement you are currently reading. Additionally, THIS SOFTWARE PRODUCT COMES WITH NO WARRANTY OF ANY KIND, EXPRESS OR IMPLIED. We cannot guarantee the ability of this product to work on every system, and while we strive to reach that goal, we are not liable if your particular hardware configuration does not work with NOS. We hope that NOS will be an enjoyable experience for you.

# I need help!

As of this writing, NOS is a one-man operation with as much of a budget as an OS can get when the sole developer is still in high school. If you would like to help, by all means, shoot me an email at nos.suppt@gmail.com, or if you feel more comfortable you can fork the repository and submit issues and pull requests as you desire. I am always open to accept help!
