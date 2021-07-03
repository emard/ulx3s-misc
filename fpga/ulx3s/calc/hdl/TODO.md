    -- TODO:
    -- [ ] function to calculate coefficients for any step
    -- [ ] coefficients for 195.3125 mm step, 512 samples / 100 m
    -- [x] extend 1-input to 2-input
    -- [x] speed up, reduce states
    -- [x] alias element calc state index cnt(2 downto 0) -> cnt(1 downto 0)
    -- [x] reduce address bits 7->6 ia,ib
    -- [x] parameter for step (other than 250 mm)
    -- [x] moving sum rvz in BRAM (parameter: track length 100 m)
    -- [ ] check numeric method for slope calculation
           Currently at 1kHz sample rate sensor noise
           generates result 2, too much (we need < 0.1)
