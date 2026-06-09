1. generate more accurate transacitons with AXI VIP
    -> with tag, target: test which can also write into tag array (keep lightweight as possible)

2. add monitor from cocotb to snoop on AXI transactions 
    -> instantiate Csaba's monitor as well
    -> ensure the two behave the same for the basic tests
    -> as a third step, add some randomization for writes and reads into both data and tag arrays

2.5 write a lightweight verification plan
    -> (example)[https://github.com/lowRISC/dvplan/tree/main/example/simple_fifo] 
    -> and (here)[https://docs.google.com/spreadsheets/d/1U8Q6Q-rClXwC7wXC2JB8XgztREFfrOPAuSDI7r6XZCw/edit?gid=506438109#gid=506438109]
    -> define some corner cases
    -> between smoke test and targeted test
    -> leave complex use cases for tag controller verification

3. After this is in place, re-sync and move to master development
    -> v1 signoff on SRAM in end of september
    -> v1 for toplevel should be in september
    -> all v1 signoffs shuold be in september