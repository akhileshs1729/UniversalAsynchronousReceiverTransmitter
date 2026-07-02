`default_nettype none
`timescale 1ns/1ps

module tb_topSystolicArray();
  parameter int unsigned N = 4;
  parameter int unsigned MAX_SIM_CYCLES = 500;
  parameter int unsigned RESET_NEG_EDGE = 5; 
  parameter int unsigned ASSERT_VALID_INPUT = (3 * N) + 3;

  logic i_clk;
  logic i_arst;
  logic [(N*N*8)-1:0] i_a; 
  logic [(N*N*8)-1:0] i_b;
  logic i_validInput;
  logic [N-1:0][N-1:0][31:0] o_c;
  logic o_validResult;

  logic [31:0] expected_matrix_c [0:N-1][0:N-1];
  int unsigned cycle_cnt;
  logic [(N*N*8)-1:0] temp_a, temp_b;

  // Hack: Unpack o_c to allow dynamic indexing in Icarus
  wire [31:0] unpacked_o_c [0:N-1][0:N-1];
  genvar gi, gj;
  generate
    for (gi = 0; gi < N; gi++) begin : gen_row
      for (gj = 0; gj < N; gj++) begin : gen_col
        assign unpacked_o_c[gi][gj] = o_c[gi][gj];
      end
    end
  endgenerate

  topSystolicArray #(.N(N)) dut (
    .i_clk(i_clk), .i_arst(i_arst), .i_a(i_a), .i_b(i_b),
    .i_validInput(i_validInput), .o_c(o_c), .o_validResult(o_validResult)
  );

  initial begin
    i_clk = 0;
    forever #5 i_clk = ~i_clk;
  end

  initial begin
    $dumpfile("waveform.vcd");
    $dumpvars(0, tb_topSystolicArray);
  end

  task automatic calculateResultMatrix();
    int a_val, b_val;
    int i, j, k;
    for (i = 0; i < N; i++) begin
      for (j = 0; j < N; j++) begin
        expected_matrix_c[i][j] = 0;
        for (k = 0; k < N; k++) begin
          a_val = (i_a >> ((i * N + k) * 8)) & 8'hFF;
          b_val = (i_b >> ((k * N + j) * 8)) & 8'hFF;
          expected_matrix_c[i][j] += a_val * b_val;
        end
      end
    end
  endtask

  task automatic displayMatrix(string matrix_name);
    int current_val, i, j;
    $display("\nMatrix %s", matrix_name);
    for (i = 0; i < N; i++) begin
      for (j = 0; j < N; j++) begin
        if (matrix_name == "A") begin
          current_val = (i_a >> ((i * N + j) * 8)) & 8'hFF;
          $write("%02x\t", current_val);
        end else if (matrix_name == "B") begin
          current_val = (i_b >> ((i * N + j) * 8)) & 8'hFF;
          $write("%02x\t", current_val);
        end else if (matrix_name == "C (Expected)") begin
          $write("%08x\t", expected_matrix_c[i][j]);
        end else if (matrix_name == "R (Received)") begin
          $write("%08x\t", unpacked_o_c[i][j]);
        end
      end
      $display("");
    end
  endtask

  initial begin
    int i;
    i_arst = 0; i_validInput = 0; i_a = '0; i_b = '0; cycle_cnt = 0;

    @(negedge i_clk); 
    i_arst = 1;
    repeat(RESET_NEG_EDGE/2) @(negedge i_clk);
    i_arst = 0;

    while (cycle_cnt < MAX_SIM_CYCLES) begin
      @(posedge i_clk);
      cycle_cnt++;

      if ((cycle_cnt % ASSERT_VALID_INPUT) == 0) begin
        temp_a = '0;
        temp_b = '0;
        for (i = 0; i < N*N; i++) begin
          temp_a = temp_a | ( ($urandom_range(0, 255) & 256'hFF) << (i * 8) );
          temp_b = temp_b | ( ($urandom_range(0, 255) & 256'hFF) << (i * 8) );
        end
        i_a = temp_a;
        i_b = temp_b;
        calculateResultMatrix();
        displayMatrix("A");
        displayMatrix("B");
        i_validInput <= 1;
      end else begin
        i_validInput <= 0;
      end
    end
    $display("\n[TIME-OUT] Maximum simulation time reached.");
    $finish;
  end

  always @(posedge i_clk) begin
    if (o_validResult) begin
      bit error_found;
      int i, j;
      error_found = 0;
      displayMatrix("C (Expected)");

      for (i = 0; i < N; i++) begin
        for (j = 0; j < N; j++) begin
          if (unpacked_o_c[i][j] !== expected_matrix_c[i][j]) begin
            error_found = 1;
          end
        end
      end

      if (error_found) begin
        $display("\n*******************************************");
        $display("ERROR: output matrix received is incorrect.");
        displayMatrix("R (Received)");
        $display("*******************************************");
        $finish;
      end else begin
        $display("\nSUCCESS: Matrix computed correctly at cycle %0d!", cycle_cnt);
      end
    end
  end
endmodule
`resetall