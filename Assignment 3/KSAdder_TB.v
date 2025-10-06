timescale 1ns / 1ps

module tb_kogge_stone_adder;

    // Parameters
    localparam WIDTH      = 16;
    localparam CLK_PERIOD = 10; // As clock frequency is 100MHz, so clk period becomes 10ns

    // Testbench Signals
    // Inputs to be applied to the DUT
    reg  [WIDTH-1:0] A;
    reg  [WIDTH-1:0] B;
    reg              CIN;
    reg              CLK;
    reg              RST_N;

    // Outputs from DUT
    wire [WIDTH-1:0] SUM;
    wire             COUT;

    // Internal testbench variables
    integer test_count;
    integer error_count;
    reg [WIDTH-1:0] expected_sum;
    reg             expected_cout;
    reg [WIDTH-1:0] A_pipelined, B_pipelined; // In order to model the DUT input registers
    reg CIN_pipelined;

    // Instantiating the DUT
    kogge_stone_adder_16bit dut (
        .A(A),
        .B(B),
        .CIN(CIN),
        .CLK(CLK),
        .RST_N(RST_N),
        .SUM(SUM),
        .COUT(COUT)
    );

    // Generating clock
    initial begin
        CLK = 0;
        forever #(CLK_PERIOD / 2) CLK = ~CLK;
    end

    // Dumping the waveform
    initial begin
        $dumpfile("waveforms.vcd");
        $dumpvars(0, tb_kogge_stone_adder);
    end

    // Applying the Test Vectors and Verifying the results
    initial begin
        test_count = 0;
        error_count = 0;

        // Applying reset
        RST_N = 1'b0; // Asserting reset
        A     = {WIDTH{1'bx}};
        B     = {WIDTH{1'bx}};
        CIN   = 1'bx;
        repeat(2) @(posedge CLK);
        RST_N = 1'b1; // De-asserting reset
		
        #1; // Offset from clock edge

        // Runing the Test Vectors
        // Test Case 1: Zeroes
        run_test(16'h0000, 16'h0000, 1'b0);

        // Test Case 2: Simple addition
        run_test(16'h0010, 16'h0025, 1'b0);

        // Test Case 3: With carry in
        run_test(16'h000A, 16'h000B, 1'b1);

        // Test Case 4: Max value for one operand
        run_test(16'hFFFF, 16'h0000, 1'b0);

        // Test Case 5: Max value + 1 (rollover)
        run_test(16'hFFFF, 16'h0001, 1'b0);
        
        // Test Case 6: Max value + 1 + CIN (rollover)
        run_test(16'hFFFF, 16'h0000, 1'b1);

        // Test Case 7: Both operands max value with CIN
        run_test(16'hFFFF, 16'hFFFF, 1'b1);
        
        // Test Case 8: Random value 1
        run_test(16'h1234, 16'h5678, 1'b0);
        
        // Test Case 9: Random value 2 with CIN
        run_test(16'hABCD, 16'hDCBA, 1'b1);

        // Runing a loop of random test cases
        repeat (20) begin
            run_test($random, $random, $random & 1);
        end
    end

    // This task applies inputs, waits for the 2-cycle latency, and checks the result.
    task run_test(input [WIDTH-1:0] test_A, input [WIDTH-1:0] test_B, input test_CIN);
    begin
        // Applying inputs on the clock edge
        @(posedge CLK);
        A = test_A;
        B = test_B;
        CIN = test_CIN;

        // Modeling the DUT's 2-cycle pipeline to calculate expected result
        // Cycle 1: Inputs are latched into DUT's internal registers
        @(posedge CLK);
        A_pipelined = A;
        B_pipelined = B;
        CIN_pipelined = CIN;
        
        // Cycle 2: Result of previous inputs appears at the DUT output
        @(posedge CLK);
        
        // Calculating expected result based on the values that were in the first pipeline stage
        {expected_cout, expected_sum} = A_pipelined + B_pipelined + CIN_pipelined;

        // Compare DUT output with expected result
        test_count = test_count + 1;
        if ({COUT, SUM} === {expected_cout, expected_sum}) begin
            $display("[%0t] PASS: Test %0d (A=%h, B=%h, Cin=%b) -> Sum=%h, Cout=%b",
                     $time, test_count, A_pipelined, B_pipelined, CIN_pipelined, SUM, COUT);
        end else begin
            $display("[%0t] FAIL: Test %0d (A=%h, B=%h, Cin=%b)",
                     $time, test_count, A_pipelined, B_pipelined, CIN_pipelined);
            $display("        Expected: Sum=%h, Cout=%b", expected_sum, expected_cout);
            $display("        Got:      Sum=%h, Cout=%b", SUM, COUT);
            error_count = error_count + 1;
        end
    end
    endtask

endmodule
