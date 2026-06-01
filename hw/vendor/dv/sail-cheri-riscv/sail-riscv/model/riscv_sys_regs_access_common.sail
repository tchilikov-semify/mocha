function get_xepc(p : Privilege) -> xlenbits =
  match p {
    Machine    => get_mepc(),
    Supervisor => get_sepc(),
    User       => internal_error(__FILE__, __LINE__, "N extension not supported"),
  }
