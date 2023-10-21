# MULTIBOOT

Flash can contain multiple bitstreams.
Press BTN0 to exit current bitstream and jump to next one.
After the last, it loads the first.

In this example, each bitstream supports exit because
it reads BTN0 and when pressed long enough (debouncing fuze),
it pulls down USER_PROGRAMN signal which exits currently
running bitstream and loads next one from flash. 

User can solder D28 diode then BTN0 changes function:
BTN0 will hard-pull PROGRAMN and unconditionally exit
any running bitstream and load next one from flash.
With D28 BTN0 can't be used as normal input button
so D28 diode is not soldered as factory default.

https://github.com/emard/ulx3s/blob/master/doc/MANUAL.md
