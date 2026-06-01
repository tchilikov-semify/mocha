class cva6_testrig_env extends uvm_env;
  cva6_testrig_agent testrig_agent;

  `uvm_component_utils(cva6_testrig_env)
  `uvm_component_new

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    testrig_agent = cva6_testrig_agent::type_id::create("testrig_agent", this);
  endfunction : build_phase
endclass
