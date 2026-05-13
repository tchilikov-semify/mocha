// Some implementations may not store the top bits of addresses. This function
// is called when an address is stored so that it can be modified accordingly.
// By default all bits are stored.
function convertInvalidAddrBits(addr : xlenbits) -> xlenbits = addr

// This is used to allow overloading by extensions that change the register
// type (e.g. CHERI).
overload convertInvalidAddr = {convertInvalidAddrBits}

// Test if an address is valid. convertInvalidAddrBits must do nothing if
// validAddr returns true, but it is allowed that some invalid addresses
// are not changed by the conversion.
function validAddr(addr : xlenbits) -> bool = true

// Test if every address in a range of addresses is valid.
function validAddrRange(addr : xlenbits, width: range(0, max_mem_access)) -> bool = true
