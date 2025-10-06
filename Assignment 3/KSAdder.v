module kogge_stone_adder_16bit(
    // Inputs
    input  wire [15:0] A,
    input  wire [15:0] B,
    input  wire        CIN,
    input  wire        CLK,
    input  wire        RST_N,

    // Outputs
    output reg  [15:0] SUM,
    output reg         COUT
);

    // Parameters and Internal Signals
    localparam WIDTH = 16; 
    localparam STAGES = $clog2(WIDTH);

    // Input Registers
    reg [WIDTH-1:0] A_reg, B_reg;
    reg CIN_reg;

    // Internal wires for combinational logic
    wire [WIDTH-1:0] p_initial, g_initial; // Initial Propagate and Generate
    wire [WIDTH-1:0] sum_comb;             // Combinational sum before output register

    // Wires for Generate/Propagate for each stage
    // p[s][i] and g[s][i], so that we can hold the P/G signals for stage 's' at bit 'i'
    wire [WIDTH-1:0] p [STAGES:1];
    wire [WIDTH-1:0] g [STAGES:1];

    // Wires for the carries into each full adder cell
    wire [WIDTH:0] carry;

    // Input Registering
    // On the rising edge of CLK, latch the inputs A, B, and CIN.
    // The registers are reset to 0 asynchronously on RST_N (active low).
    always @(posedge CLK or negedge RST_N) begin
        if (!RST_N) begin
            A_reg   <= {WIDTH{1'b0}};
            B_reg   <= {WIDTH{1'b0}};
            CIN_reg <= 1'b0;
        end else begin
            A_reg   <= A;
            B_reg   <= B;
            CIN_reg <= CIN;
        end
    end

    // Combinational Logic: Kogge-Stone Adder

    // Initial Propagate and Generate Signal Calculation,can be calculated from the registered inputs.
    // p[i] = A[i] ^ B[i]
    // g[i] = A[i] & B[i]
    assign p_initial = A_reg ^ B_reg;
    assign g_initial = A_reg & B_reg;

    // Parallel Prefix Network for Carry Calculation
    // This network computes the group Propagate and Generate signals in 4 stages.
    // The '•' operator is defined as: (g1, p1) • (g0, p0) = (g1 | (p1 & g0), p1 & p0)
    genvar s, i; // loop variables for generate block (stage and bit index)

    generate
        for (i = 0; i < WIDTH; i = i + 1) begin : stage1_logic
            if (i >= 1) begin
                assign g[1][i] = g_initial[i] | (p_initial[i] & g_initial[i-1]);
                assign p[1][i] = p_initial[i] & p_initial[i-1];
            end else begin // Bit 0 passes through
                assign g[1][i] = g_initial[i];
                assign p[1][i] = p_initial[i];
            end
        end

        // Stages 2,3 &4
        for (s = 2; s <= STAGES; s = s + 1) begin : prefix_stages_logic
            for (i = 0; i < WIDTH; i = i + 1) begin : bit_logic
                if (i >= (1 << (s-1))) begin
                    assign g[s][i] = g[s-1][i] | (p[s-1][i] & g[s-1][i-(1<<(s-1))]);
                    assign p[s][i] = p[s-1][i] & p[s-1][i-(1<<(s-1))];
                end else begin // Bits that are not wide enough for the operator pass through
                    assign g[s][i] = g[s-1][i];
                    assign p[s][i] = p[s-1][i];
                end
            end
        end
    endgenerate

    // Final Carry Calculation
    // The carries are generated from the final stage of the prefix network.
    // c[i] = G_final[i-1] | (P_final[i-1] & CIN)
    assign carry[0] = CIN_reg;
    assign carry[WIDTH:1] = g[STAGES] | (p[STAGES] & {WIDTH{CIN_reg}});

    // Final Sum Calculation
    // The sum is calculated using the initial propagate signals and the final carries.
    // sum[i] = p_initial[i] ^ carry[i]
    assign sum_comb = p_initial ^ carry[WIDTH-1:0];

    // Output Registering
    // On the rising edge of CLK, latch the combinational results.
    // The registers are reset to 0 asynchronously on RST_N (active low).
    always @(posedge CLK or negedge RST_N) begin
        if (!RST_N) begin
            SUM  <= {WIDTH{1'b0}};
            COUT <= 1'b0;
        end else begin
            SUM  <= sum_comb;
            COUT <= carry[WIDTH];
        end
    end

endmodule
