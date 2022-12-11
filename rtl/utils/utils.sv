//
// some common functionality used in this project
//
`timescale 1ns/100ps
/////////////////////////////////////////////
// EECS 470 provided modules [TRUTH]
/////////////////////////////////////////////
  // EECS 470 - Winter 2009
  //
  // parametrized priority encoder (really just an encoder)
  // parameter is output width
  //
    module pe(gnt,enc);
      //synopsys template
      parameter OUT_WIDTH=4;
      parameter IN_WIDTH =1<<OUT_WIDTH;

      input   [IN_WIDTH-1:0] gnt;
      output [OUT_WIDTH-1:0] enc;

      wor    [OUT_WIDTH-1:0] enc;
      
      genvar i,j;
      generate
        for(i=0;i<OUT_WIDTH;i=i+1)
        begin : foo
          for(j=1;j<IN_WIDTH;j=j+1)
          begin : bar
            if (j[i])
              assign enc[i] = gnt[j];
          end
        end
      endgenerate
    endmodule

    /*
      wand_sel - Priority selector module.
    */
      //MSB top priority.
      module wand_sel (req,gnt);
        //synopsys template
        parameter WIDTH=64;
        input wire  [WIDTH-1:0] req;
        output wand [WIDTH-1:0] gnt;

        wire  [WIDTH-1:0] req_r;
        wand  [WIDTH-1:0] gnt_r;

        //priority selector
        genvar i;
        // reverse inputs and outputs
        for (i = 0; i < WIDTH; i = i + 1)
        begin : reverse
          assign req_r[WIDTH-1-i] = req[i];
          assign gnt[WIDTH-1-i]   = gnt_r[i];
        end

        for (i = 0; i < WIDTH-1 ; i = i + 1)
        begin : foo
          assign gnt_r [WIDTH-1:i] = {{(WIDTH-1-i){~req_r[i]}},req_r[i]};
        end
        assign gnt_r[WIDTH-1] = req_r[WIDTH-1];

      endmodule

    /*
      Joshua Smith (smjoshua@umich.edu)
      psel_gen.v - Parametrizable priority selector module
      Module is parametrizable in the width of the request bus (WIDTH), and the
      number of simultaneous requests granted (REQS).
    */
      // allocate REQS resources.
      // search up and down....
      module psel_gen ( // Inputs
                        req,
                      
                        // Outputs
                        gnt,
                        gnt_bus,
                        empty
                      );

        // synopsys template
        parameter REQS  = 3;
        parameter WIDTH = 128;

        // Inputs
        input wire  [WIDTH-1:0]       req;

        // Outputs
        output wor  [WIDTH-1:0]       gnt;
        output wand [WIDTH*REQS-1:0]  gnt_bus;
        output wire                   empty;

        // Internal stuff
        wire  [WIDTH*REQS-1:0]  tmp_reqs;
        wire  [WIDTH*REQS-1:0]  tmp_reqs_rev;
        wire  [WIDTH*REQS-1:0]  tmp_gnts;
        wire  [WIDTH*REQS-1:0]  tmp_gnts_rev;

        // Calculate trivial empty case
        assign empty = ~(|req);
        
        genvar j, k;
        for (j=0; j<REQS; j=j+1)
        begin:foo
          // Zero'th request/grant trivial, just normal priority selector
          if (j == 0) begin
            assign tmp_reqs[WIDTH-1:0]  = req[WIDTH-1:0];
            assign gnt_bus[WIDTH-1:0]   = tmp_gnts[WIDTH-1:0];

          // First request/grant, uses input request vector but reversed, mask out
          //  granted bit from first request.
          end else if (j == 1) begin
            for (k=0; k<WIDTH; k=k+1)
            begin:Jone
              assign tmp_reqs[2*WIDTH-1-k] = req[k];
            end

            assign gnt_bus[2*WIDTH-1 -: WIDTH] = tmp_gnts_rev[2*WIDTH-1 -: WIDTH] & ~tmp_gnts[WIDTH-1:0];

          // Request/grants 2-N.  Request vector for j'th request will be same as
          //  j-2 with grant from j-2 masked out.  Will alternate between normal and
          //  reversed priority order.  For the odd lines, need to use reversed grant
          //  output so that it's consistent with order of input.
          end else begin    // mask out gnt from req[j-2]
            assign tmp_reqs[(j+1)*WIDTH-1 -: WIDTH] = tmp_reqs[(j-1)*WIDTH-1 -: WIDTH] &
                                                      ~tmp_gnts[(j-1)*WIDTH-1 -: WIDTH];
            
            if (j%2==0)
              assign gnt_bus[(j+1)*WIDTH-1 -: WIDTH] = tmp_gnts[(j+1)*WIDTH-1 -: WIDTH];
            else
              assign gnt_bus[(j+1)*WIDTH-1 -: WIDTH] = tmp_gnts_rev[(j+1)*WIDTH-1 -: WIDTH];

          end

          // instantiate priority selectors
          wand_sel #(WIDTH) psel (.req(tmp_reqs[(j+1)*WIDTH-1 -: WIDTH]), .gnt(tmp_gnts[(j+1)*WIDTH-1 -: WIDTH]));

          // reverse gnts (really only for odd request lines)
          for (k=0; k<WIDTH; k=k+1)
          begin:rev
            assign tmp_gnts_rev[(j+1)*WIDTH-1-k] = tmp_gnts[(j)*WIDTH+k];
          end

          // Mask out earlier granted bits from later grant lines.
          // gnt[j] = tmp_gnt[j] & ~tmp_gnt[j-1] & ~tmp_gnt[j-3]...
          for (k=j+1; k<REQS; k=k+2)
          begin:gnt_mask
            assign gnt_bus[(k+1)*WIDTH-1 -: WIDTH] = ~gnt_bus[(j+1)*WIDTH-1 -: WIDTH];
          end
        end

        // assign final gnt outputs
        // gnt_bus is the full-width vector for each request line, so OR everything
        for(k=0; k<REQS; k=k+1)
        begin:final_gnt
          assign gnt = gnt_bus[(k+1)*WIDTH-1 -: WIDTH];
        end

      endmodule


////////////////////////////////////////////////////////////
// some common functions
////////////////////////////////////////////////////////////
  // [CHECKED]
  // example input 0110, example output 2100
  module running_sum (
    in, sum
  );
    // synopsys template
    parameter WIDTH   = 4;
    parameter WIDTH_W = $clog2(WIDTH);
    parameter START   = 0;

    // Inputs
    input [WIDTH-1:0] in;

    // Outputs
    output logic [WIDTH-1:0] [WIDTH_W-1:0] sum;

    assign sum[0] = START;
    genvar i;
    generate
      for (i = 1; i < WIDTH; i = i + 1) begin
        assign sum[i] = sum[i - 1] + in[i - 1];
      end
    endgenerate
  endmodule

  // [CHECKED]
  // example input 1010110, example output 0001111 
  module align_bits (
    in, out
  );
    // synopsys template
    parameter WIDTH   = 4;

    // Inputs
    input [WIDTH-1:0] in;

    // Outputs
    output logic [WIDTH-1:0] out;

    logic [WIDTH:0] [WIDTH*2-1:0] tmp;
    assign tmp[0] = {{WIDTH{1'b0}}, {WIDTH{1'b1}}};
    assign out    = tmp[WIDTH][WIDTH*2-1:WIDTH];

    genvar i;
    generate
      for (i = 1; i <= WIDTH; i = i + 1) begin
        assign tmp[i] = tmp[i-1] << in[i-1];
      end 
    endgenerate
  endmodule

  // [CHECKED]
  // example input 10010, exmple output 00041
  module seq_encode (
    in, code
  );
    // synopsys template
    parameter WIDTH   = 4;
    parameter WIDTH_W = $clog2(WIDTH);

    // Inputs
    input [WIDTH-1:0] in;

    // Outputs
    output logic [WIDTH-1:0] [WIDTH_W-1:0] code;


    logic [WIDTH:0] [WIDTH-1:0] [WIDTH_W-1:0] code_fill;

    logic [WIDTH_W:0]                         total; // e.g. 2
    always_comb begin
        total = 0;
        for (int k = 0; k < WIDTH; k = k + 1) begin
            total = total + in[k];
        end
    end

    // 0000 -> i:1, 0000 -> i:2, 1000 -> i:3, 1000 -> i:4, 3100 => 0031 
    assign code_fill[0] = {WIDTH * WIDTH_W{1'b0}};
    genvar i;
    generate 
        for (i = 1; i < WIDTH + 1; i = i + 1) begin
            assign code_fill[i] = in[i - 1] ? {i - 1, code_fill[i - 1][WIDTH-1:1]} : code_fill[i - 1];
        end
    endgenerate
    assign code = code_fill[WIDTH] >> ((WIDTH - total) * WIDTH_W);
  endmodule

  // [CHECKED]
  // example input 10111, example output 00111
  module running_and (
    in, out
  );
    // synopsys template
    parameter WIDTH   = 4;

    // Inputs
    input [WIDTH-1:0] in;

    // Outputs
    output logic [WIDTH-1:0] out;

    assign out[0] = in[0];
    genvar i;
    generate
      for (i = 1; i < WIDTH; i = i + 1) begin
        assign out[i] = in[i] & out[i - 1];
      end 
    endgenerate
  endmodule

  // [CHECKED]
  // example input 01001, example output 00111
  // select the region [start, end)
  // left shift to select (start, end]
  module running_xor (
    in, out
  );
    // synopsys template
    parameter WIDTH   = 4;

    // Inputs
    input [WIDTH-1:0] in;

    // Outputs
    output logic [WIDTH-1:0] out;

    assign out[0] = in[0];
    genvar i;
    generate
      for (i = 1; i < WIDTH; i = i + 1) begin
        assign out[i] = in[i] ^ out[i - 1];
      end 
    endgenerate
  endmodule

  // [CHECKED]
  // example input 01000, example output 11000
  // select the region after the lowest bit (including)
  module running_or (
    in, out
  );
    // synopsys template
    parameter WIDTH   = 4;

    // Inputs
    input [WIDTH-1:0] in;

    // Outputs
    output logic [WIDTH-1:0] out;

    assign out[0] = in[0];
    genvar i;
    generate
      for (i = 1; i < WIDTH; i = i + 1) begin
        assign out[i] = in[i] | out[i - 1];
      end 
    endgenerate
  endmodule

  // [CHECKED]
  // e.g. in:0010010 out:0000010
  module first_one (
    in, out
  );
    // synopsys template
    parameter WIDTH   = 4;

    // Inputs
    input [WIDTH-1:0] in;

    // Outputs
    output logic [WIDTH-1:0] out;

    logic [WIDTH-1:0] out_shadow;
    running_or #(.WIDTH(WIDTH)) t (.in(in), .out(out_shadow));
    assign out = in & ~(out_shadow << 1);
  endmodule

  // [CHECKED] lower than 0 is meaningless so lower than 0 output 0001
  module bits_lower (
    in, out
  );
    // synopsys template
    parameter IN_WIDTH   = 4;
    parameter OUT_WIDTH  = 1 << IN_WIDTH;

    // Inputs
    input [IN_WIDTH-1:0] in;
    // Outputs
    output [OUT_WIDTH-1:0] out;

    logic [OUT_WIDTH*2-1:0] out_tmp;
    assign out_tmp = {{OUT_WIDTH{1'b0}}, {OUT_WIDTH{1'b1}}} << in;
    assign out = out_tmp[OUT_WIDTH*2-1:OUT_WIDTH];
  endmodule

  // [CHECKED]
  module replicate_words (
    in, out
  );
    // synopsys template
    parameter IN_WIDTH = 8;
    parameter TIMES = 4;
    localparam OUT_WIDTH = IN_WIDTH * TIMES;

    // Inputs
    input [IN_WIDTH-1:0] in;

    // Outputs
    output [OUT_WIDTH-1:0] out;

    assign out = {TIMES{in}};
  endmodule

  // [CHECKED// through reverse bits]
  module reverse_words (
    in, out
  );
    // synopsys template
    parameter WIDTH = 8;
    parameter SZ = 8;
    // Inputs 
    input [WIDTH-1:0] [SZ-1:0] in;
    
    // Outputs
    output [WIDTH-1:0] [SZ-1:0] out;
    generate
      genvar i;
      for (i = 0; i < WIDTH; i++) begin
        assign out[i] = in[WIDTH-1-i];
      end
    endgenerate
    
  endmodule

  // [CHECKED]
  module reverse_bits (
    in, out
  );
    // synopsys template
    parameter WIDTH = 8;

    // Inputs 
    input [WIDTH-1:0] in;
    
    // Outputs
    output [WIDTH-1:0] out;
    reverse_words #(.WIDTH(WIDTH), .SZ(1)) key (.*);
  endmodule

  // [CHECKED]
  module element_cmp (A, B, match);
    // synopsys template
    parameter SZ = 8; // size

    /////////////// IO ///////////////
    input [SZ-1:0] A, B;

    output         match;
    //////////////////////////////////

    assign match = A == B;
  endmodule

  // [CHECKED]
  // output a bit vector representing which part match
  // the tag
  module list_cmp(As, Bs, match);
    // synopsys template
    parameter L  = 5; // how many to compare
    parameter SZ = 8; // size

    /////////////// IO ///////////////
    input [L-1:0] [SZ-1:0] As, Bs;

    output [L-1:0]         match;
    //////////////////////////////////

    element_cmp #(.SZ(SZ)) els [L-1:0] (.A(As), .B(Bs), .match(match));
  endmodule

  // [CHECKED]
  module expand_mask ( in, out );
    // synopsys template
    parameter L  = 5; // # of bits in mask
    parameter SZ = 8; // size to scale
    
    input [L-1:0] in;
    output [L-1:0] [SZ-1:0] out;

    generate
      genvar i;
      for (i = 0; i < L; i++) begin
        assign out[i] = {SZ{in[i]}};   
      end
    endgenerate
  endmodule

  // [CHECKED]
  // e.g. in=4 out=0010000 OUT_WIDTH=7 IN_WIDTH=3
  module to_one_hot ( in, out);
    //synopsys template
    parameter IN_WIDTH= 4;
    parameter OUT_WIDTH= 1 << IN_WIDTH;

    /////////////// IO ///////////////
    input [IN_WIDTH-1:0] in;
    output [OUT_WIDTH-1:0] out;
    //////////////////////////////////
    logic [OUT_WIDTH-1:0] out_base;
    assign out_base = {OUT_WIDTH{1'b0}} | 1;
    assign out = out_base << in;
  endmodule

  // [CHECKED]
  // every high bit in b, has corresponding bit in a high
  // a covers b ?
  module bits_cover (
    a, b, out
  );
    // synopsys template
    parameter SZ = 8;

    input [SZ-1:0] a, b;
    output wand out;
    generate
      genvar i;
      for (i = 0; i < SZ; i++) begin
        assign out = b[i] ? a[i] : 1;
      end 
    endgenerate
  endmodule

  // [CHECKED]
  // row vector x col vector using and as the operator
  module vec_cross_and ( rv, cv, m );
    // synopsys template
    parameter N = 5;
    parameter M = 5;

    input [N-1:0] rv;
    input [M-1:0] cv;
    output [N-1:0] [M-1:0] m; 

    generate
      genvar i, j;
      for (i = 0; i < N; i++) begin
        for (j = 0; j < M; j++) begin
          assign m[i][j] = rv[i] & cv[j];
        end 
      end
    endgenerate
  endmodule

  // [CHECKED]
  // traverse a NxM matrix to MxN
  module matrix_t (
    in, out
  );
    // synopsys template
    parameter N = 5;
    parameter M = 5;

    input [N-1:0] [M-1:0] in;
    output [M-1:0] [N-1:0] out;

    generate
      genvar i, j;
      for (i = 0; i < N; i++) begin
        for (j = 0; j < M; j++) begin
          assign out[j][i] = in[i][j];  
        end
      end
    endgenerate
  endmodule

////////////////////////////////////////////////////////////
// gather and scatter
////////////////////////////////////////////////////////////
  // [CHECKED]
  // gather in order: in end (1010), out end (0011)
  module gather_in_order (
    valids_in, data_in, valids_out, data_out
  );
    // synopsys template
    parameter SZ = 7; // how many to gather
    parameter W = 3; // data width
    /////////////// IO ///////////////
    input [SZ-1:0] valids_in;
    input [SZ-1:0] [W-1:0] data_in; 
    output [SZ-1:0] valids_out;
    output [SZ-1:0] [W-1:0] data_out; 
    //////////////////////////////////

    localparam SZ_W = $clog2(SZ);
    logic [SZ-1:0] [SZ_W-1:0] num1before;
    running_sum #(.WIDTH(SZ)) nb (.in(valids_in), .sum(num1before));

    logic [SZ-1:0] [W-1:0] masked_data;

    wor [SZ-1:0] map_valids;
    wor [SZ-1:0] [W-1:0] map_data;
    assign map_valids = 0;
    assign map_data   = 0;
    generate
      genvar i;
      for (i = 0; i < SZ; i++) begin
        assign masked_data[i] = data_in[i] & {W{valids_in[i]}};
        assign map_valids     = valids_in[i] << num1before[i];
        assign map_data       = masked_data[i] << (num1before[i] * W);
      end
    endgenerate
    assign valids_out = map_valids;
    assign data_out   = map_data;
  endmodule

  // [CHECKED]
  // scatter to 1ones in order, in end (0011) out end req (1101) => (0101)
  module scatter_in_order (
    valids_in, data_in, valids_out, data_out, reqs
  );
    // synopsys template
    parameter SZ = 7; // how many to scatter
    parameter W = 3; // data width
    /////////////// IO ///////////////
    input [SZ-1:0] reqs;
    input [SZ-1:0] valids_in;
    input [SZ-1:0] [W-1:0] data_in; 
    output [SZ-1:0] valids_out;
    output [SZ-1:0] [W-1:0] data_out; 
    //////////////////////////////////
    localparam SZ_W = $clog2(SZ);
    logic [SZ-1:0] [SZ_W-1:0] num1before;
    running_sum #(.WIDTH(SZ)) nb (.in(reqs), .sum(num1before));

    logic [SZ-1:0] valids_map;
    generate
      genvar i;
      for (i = 0; i < SZ; i++) begin
        assign valids_map[i] = valids_in[num1before[i]];
        assign data_out[i]   = data_in[num1before[i]];
      end
    endgenerate
    assign valids_out = valids_map & reqs;
  endmodule

////////////////////////////////////////////////////////////
// reduction operations
////////////////////////////////////////////////////////////
  // do or reduction all all ins, produces a out. only ens == 1 will be reducted
  // if ens are all 0, out will be 0
  module reduction_or ( ins, out , ens);
    // synopsys template
    parameter SZ = 5;
    parameter O = 8; // word size

    input [O-1:0] [SZ-1:0] ins;
    input [O-1:0] ens;
    output wor [SZ-1:0] out; 

    generate
      genvar i;
      for (i = 0; i < O; i++) begin
        assign out = ins[i] & {SZ{ens[i]}};
      end
    endgenerate
  endmodule

  // replace din, with dr based on m.
  // REQ: m doesnot overlap, so each bit use a one hot to do replace.
  module reduction_replace ( din, dr, m, dout, ens );
    // synopsys template
    parameter SZ = 5;
    parameter O = 8; // word size

    input [O-1:0] [SZ-1:0] dr, m;
    input [SZ-1:0] din;
    input [O-1:0] ens;
    output [SZ-1:0] dout; 

    logic [SZ-1:0] same_r, dr_reduced;
    reduction_or #(.SZ(SZ), .O(O)) same_r_gen (.ins(m), .out(same_r), .ens);
    reduction_or #(.SZ(SZ), .O(O)) dr_reduced_gen (.ins(dr & m), .out(dr_reduced), .ens);
    assign dout = (din & ~same_r) | dr_reduced;
  endmodule

  // wrap general_replace for 2d case, enhence readability
  module reduction_replace_2d (din, dr, m, dout, ens);
    // synopsys template
    parameter N = 5;
    parameter M = 5;
    parameter O = 8; // word size
    localparam SZ = N * M;

    input [O-1:0] [N-1:0] [M-1:0] dr, m;
    input [N-1:0] [M-1:0] din;
    input [O-1:0] ens;
    output [N-1:0] [M-1:0] dout; 

    reduction_replace #(.SZ(SZ), .O(O)) key (.*);
  endmodule

  // one hot output
  module one_hot_output(source, which, out);
    // synopsys template
    parameter L  = 5; // # of slot
    parameter SZ = 8; // word size

    /////////////// IO ///////////////
    input [L-1:0] [SZ-1:0]  source;
    input [L-1:0] which;

    output [SZ-1:0] out; 
    //////////////////////////////////
    reduction_or #(.SZ(SZ), .O(L)) ror (.ins(source), .out(out), .ens(which));
  endmodule
////////////////////////////////////////////////////////////
// table related functions
////////////////////////////////////////////////////////////
  // for a NxM matrix
  // replace the region being covered by rm, cm
  // if rm is one hot -> write a row
  // if rm is a mask -> broadcast to N row
  module wreqs_row_overwrite (rm, cm, d, dr, m);
    // synopsys template
    parameter N = 5;
    parameter M = 5;

    input [N-1:0] rm;
    input [M-1:0] cm;
    input [M-1:0] d;
    output [N-1:0] [M-1:0] dr;
    output [N-1:0] [M-1:0] m;

    vec_cross_and #(.N(N), .M(M)) m_gen (.rv(rm), .cv(cm), .m);
    generate
      genvar i;
      for (i = 0; i < N; i++) begin
        assign dr[i] = d;
      end
    endgenerate
  endmodule

  // freelist update logic (see also fifo_update_logics)
  module freelist_update_logics (
    valids, valids_i, // actually the ith is the old for the ith
    areqs, aresp, aready,
    dreqs, dpos,

    empty
  );
    // synopsys template
    parameter SZ = 7;
    parameter SZ_W = $clog2(SZ);
    parameter NA = 3;
    parameter ND = 2;

    /////////////// IO ///////////////
    input [SZ-1:0] valids; 
    output [NA:0] [SZ-1:0] valids_i; 

    input [NA-1:0] areqs; // here still assume 0111 like arrangment
    output [NA-1:0] [SZ-1:0] aresp;
    output [NA-1:0] aready;

    input [ND-1:0] [SZ-1:0] dpos;
    input [ND-1:0] dreqs; 

    // trivial empty
    output empty;
    //////////////////////////////////

    // fire signals
    logic [ND-1:0] dfire;
    logic [NA-1:0] afire;
    assign dfire = dreqs;
    assign afire = aready & areqs;

    logic [SZ-1:0] idle, valids_after_d;
    logic [SZ-1:0] d_portion;
    assign idle              = ~valids;
    psel_gen #(.REQS(NA), .WIDTH(SZ)) psel_0 (
      .req(idle), .gnt(), .gnt_bus(aresp), .empty(empty)
    );

    reduction_or #(.SZ(SZ), .O(ND)) d_portion_gen (
      .ins(dpos), .out(d_portion), .ens(dreqs)
    );

    assign valids_after_d    = valids & ~d_portion;
    assign valids_i[0] = valids_after_d;
    generate
      genvar i;
      for (i = 0; i < NA; i++) begin
        assign valids_i[i + 1] = valids_i[i] | (aresp[i] & {SZ{afire[i]}});
        assign aready[i] = |(aresp[i]);
      end
    endgenerate
  endmodule

////////////////////////////////////////////////////////////
// FIFO related functions
////////////////////////////////////////////////////////////
  // [CHECKED]
  // output ready based on valids.
  // update head, tail, valids based on fire, head, tail, valids
  // also output update details
  // req: NE, ND < SZ
  module fifo_update_logics(
    valids, valids_i,
    head, head_i, head_o, // head_o for output
    tail, tail_i,

    ereqs, eready,
    dreqs, dready
  );
    // synopsys template
    parameter SZ = 7;
    parameter SZ_W = $clog2(SZ);
    parameter NE = 3;
    parameter ND = 2;

    /////////////// IO ///////////////
    input [SZ-1:0]         valids; // e.g. 1100111
    output [NE:0] [SZ-1:0] valids_i; // e.g. 0011111 0001111 0000111

    input [SZ-1:0]         head, tail; // e.g. 0100000, 0001000
    output [ND:0] [SZ-1:0] head_i, head_o; // e.g. 0000001, 1000000, 0100000
    output [NE:0] [SZ-1:0] tail_i; // e.g. 0100000, 0100000, 0010000, 0001000

    input [NE-1:0]  ereqs; // e.g. 111
    output [NE-1:0] eready; // e.g. 011
    input [ND-1:0]  dreqs; // e.g. 11
    output [ND-1:0] dready; // e.g. 11
    //////////////////////////////////

    logic [SZ_W-1:0] head_num, tail_num; // e.g. 5, 3 (offset actually)
    pe #(.OUT_WIDTH(SZ_W), .IN_WIDTH(SZ)) enc_head (.gnt(head), .enc(head_num));
    pe #(.OUT_WIDTH(SZ_W), .IN_WIDTH(SZ)) enc_tail (.gnt(tail), .enc(tail_num));

    // since valids loops, cancaneta two will create a whole map
    // from the view point of head & tail starting from 0
    logic [SZ*2-1:0] valids_all;
    assign valids_all = {valids, valids}; // e.g. 11001111100111

    assign dready = valids_all >> head_num; // e.g. 110011111|<-00111
    assign eready = ~(valids_all >> tail_num); // e.g. ~(11001111100)|<-111

    logic [NE-1:0] efire; // e.g. 011
    logic [ND-1:0] dfire; // e.g. 11
    assign efire = ereqs & eready;
    assign dfire = dreqs & dready;

    // due to the needs of lq, first d, then emplace each
    wor [SZ-1:0] portion_d;
    assign valids_i[0] = ~(portion_d) & valids;
    // update tail and head
    assign head_i[0] = head;
    assign head_o[0] = head;
    assign tail_i[0] = tail;

    logic [NE-1:0] [NE-1:0] efire_each; // e.g. 000, 010, 001
    logic [ND-1:0] [ND-1:0] dfire_each; // e.g. 10, 01
    generate
      genvar i;
      for (i = 0; i < NE; i++) begin
        assign efire_each[i] = (1'b1 << i) & efire;    
        assign tail_i[i + 1] = |(efire_each[i]) ? {tail_i[i][SZ-2:0], tail_i[i][SZ-1]} : tail_i[i];
        assign valids_i[i + 1] = valids_i[i] | (tail_i[i] & {SZ{|(efire_each[i])}});
      end

      for (i = 0; i < ND; i++) begin
        assign dfire_each[i] = (1'b1 << i) & dfire;    
        assign head_i[i + 1] = |(dfire_each[i]) ? {head_i[i][SZ-2:0], head_i[i][SZ-1]} : head_i[i];;
        assign head_o[i + 1] = {head_i[i][SZ-2:0], head_i[i][SZ-1]};
        assign portion_d = head_i[i] & {SZ{|(dfire_each[i])}};
      end
    endgenerate
  endmodule

  // [CHECKED] 
  // it get names as fifo_old_tail_logic as it is decoupled during the process
  // of implementing reset tail mechenism of circular buffer.
  // given a old tail younger than tail in the LSB -> MSB circular order, 
  // clear all the valid bits within the potentially wrapped interval
  // [old_tail, tail)
  module fifo_old_tail_logic ( valids, tail, old_tail, valids_out);
    // synopsys template
    parameter SZ = 7;

    /////////////// IO ///////////////
    input [SZ-1:0] valids; 
    input [SZ-1:0] tail, old_tail;
    output [SZ-1:0] valids_out;
    //////////////////////////////////

    logic [SZ-1:0] cover_tmp;
    running_or #(.WIDTH(SZ)) c_0 (.in(tail), .out(cover_tmp));
    
    logic wrap, no_move;
    assign no_move = (old_tail == tail) & ~|(old_tail & valids);
    assign wrap = |(cover_tmp & old_tail) & |(old_tail & valids);
  

    logic [SZ*2-1:0] r_pivot, r_region;
    assign r_pivot = wrap ? {({{SZ*2{1'b0}}| tail} << SZ) | old_tail} : {tail | old_tail};
    running_xor #(.WIDTH(2*SZ)) r_0 (.in(r_pivot), .out(r_region));
    assign valids_out = no_move ? valids : (valids & (~(r_region[SZ-1:0])) & (~(r_region[2*SZ-1:SZ])));
  endmodule

  // [CHECKED] 
  // it turns out that the old tail logic can be used to select a region
  // select L[front, back)H. if empty is 1, the output will always be 0.
  // can select potential [front, back-1] if we set empty when front == back
  module fifo_region_select (front, back, empty, region);
    // synopsys template
    parameter SZ = 7;

    /////////////// IO ///////////////
    input [SZ-1:0] front, back;
    input empty;
    output [SZ-1:0] region;
    //////////////////////////////////
    logic [SZ-1:0] region_r;
    fifo_old_tail_logic #(.SZ(SZ)) key (
      .valids('1), .tail(back), .old_tail(front), .valids_out(region_r)
    );
    assign region = empty ? '0 : ~region_r;
  endmodule

  // [CHECKED] 
  // select the 1 that is closest to pivot, pivot
  // is in the high position. (does not include pivot)
  // e.g. 00010000 is the pivot
  // 00110111 sel 00000100 
  module fifo_wand_sel (
    in, pivot, out
  );
    // synopsys template
    parameter SZ = 7;

    /////////////// IO ///////////////
    input [SZ-1:0] in, pivot;
    output [SZ-1:0] out;
    //////////////////////////////////

    logic [SZ-1:0] no_high, no_high_in;
    running_or #(.WIDTH(SZ)) nh (.in(pivot), .out(no_high));
    assign no_high_in = in & ~(no_high);

    logic [SZ*2-1:0] expanded_in, expanded_out;
    assign expanded_in = {no_high_in, in};

    wand_sel #(.WIDTH(2*SZ)) rsel (.req(expanded_in), .gnt(expanded_out));
    assign out = expanded_out[2*SZ-1:SZ] | expanded_out[SZ-1:0];
  endmodule

////////////////////////////////////////////////////////////
// Branch mask related utilities
// all memory element in the backend use the same logic
////////////////////////////////////////////////////////////
  // [CHECKED//through br slot]
  // module: slot_logic
  // a slot can be occupied if it is empty or it is full & it is being
  // read
  module slot_logic(
    valid, out_ready, to_kill,
    in_ready
  );
    /////////////// IO ///////////////
    input valid;
    input out_ready;
    input to_kill;

    output in_ready;
    //////////////////////////////////
    assign in_ready = (!valid) || (valid && out_ready) || to_kill;
  endmodule

  // [CHECKED]
  // check branch, dtype should have field branch_mask
  module br_check (data_packet, brup_packet, brup_valid, to_kill);
    // synopsys template
    parameter type dtype = EX_PACKET;

    input dtype data_packet;
    input BRUP_PACKET brup_packet;
    input brup_valid;
    output to_kill;

    assign to_kill = brup_valid & |(data_packet.branch_mask & ((brup_valid & brup_packet.mispredict) << brup_packet.branch_idx));
  endmodule

  // [CHECKED]
  module br_clear (data_packet, brup_packet, brup_valid, clear_mask);
    // synopsys template
    parameter type dtype = EX_PACKET;
    
    input dtype data_packet;
    input BRUP_PACKET brup_packet;
    input brup_valid;
    output dtype clear_mask;

    always_comb begin
      clear_mask = data_packet;
      if (brup_valid) begin
        clear_mask.branch_mask = data_packet.branch_mask & ~(1 << brup_packet.branch_idx);
      end
    end
  endmodule


  // [CHECKED]
  // module: register_br_valid
  // description:
  // dtype should have a branch_mask.
  // a register that carry a branch mask and will check
  // a brupdate. raises a to_kill signal if the br update packet is 
  // a mispredict & clear valid bit. 
  // output will clear the br mask bit either mispredict or
  // not. data part act exactly like a plain register
  //
  // when there is both a brupdate and a in_en, the input will be treated exactly
  // as the storing data before they are captured, as we do not process the
  // output when there is a kill. also, making wiring back from out to in, and do some
  // transformatoin between possible
  //
  // when en to capture a new data, valid will be set to high if there is not
  // matching misprediction
  module register_br_valid(
    clock, reset, flush, pop, 
    data_in, en, 
    data_out, valid, 
    brup_packet, brup_valid, to_kill
  );
    // synopsys template
    parameter type dtype = WB_PACKET;

    /////////////// IO ///////////////
    input clock, reset, flush, pop; // when there is no en, clear in next cycle
    
    // d
    input dtype data_in;
    input en;

    // q
    output dtype data_out;
    output logic valid;

    // br update part
    input BRUP_PACKET brup_packet;
    input brup_valid;

    // check
    output logic to_kill;
    //////////////////////////////////

    logic valid_next;
    logic [$bits(dtype)-1:0] data_next_sel, data_next;
    assign data_next_sel = en ? data_in : 
                           pop ? 0      :
                           data_out;
    // check to kill ?
    logic to_kill_reg, to_kill_in;
    br_check #(.dtype(dtype)) check_next_in (.data_packet(data_in), .to_kill(to_kill_in), .*);
    br_check #(.dtype(dtype)) check_next_reg (.data_packet(data_out), .to_kill(to_kill_reg), .*);
    // to_kill is to kill the current reg
    assign to_kill = to_kill_reg;
    // clear the branch bit for input and 
    br_clear #(.dtype(dtype)) next_clear (.data_packet(data_next_sel), .clear_mask(data_next), .*);
    assign valid_next = en                   ? ~to_kill_in :
                        (to_kill_reg || pop) ? 0:
                        valid;

    // synopsys sync_set_reset "reset"
    always_ff @( posedge clock ) begin
      if (reset) begin
        data_out <= 0;
        valid    <= 0;
      end else begin
        data_out <= flush ? 0 : data_next;
        valid    <= flush ? 0 : valid_next;
      end
    end
  endmodule


  // [CHECKED]
  // module: register_br_slot
  // a subclass of register_br_valid. it provides ready/valid protocol.
  // it will be ready if it is not valid or it is valid and a out transcation happens.
  module register_br_slot(
    clock, reset, flush, 
    data_in, in_valid, in_ready, 
    data_out, out_valid, out_ready, 
    brup_packet, brup_valid, to_kill
  );
    // synopsys template
    parameter type dtype = WB_PACKET;

    /////////////// IO ///////////////
    input clock, reset, flush;
    
    // d
    input dtype data_in;
    input in_valid, out_ready;

    // q
    output dtype data_out;
    output out_valid, in_ready;

    // br update part
    input BRUP_PACKET brup_packet;
    input brup_valid;

    // check
    output logic to_kill;
    //////////////////////////////////

    slot_logic s(.valid(out_valid), .*);
    logic in_fire, out_fire;
    assign in_fire = in_valid & in_ready;
    assign out_fire = out_ready & out_valid;

    register_br_valid #(.dtype(dtype)) internal_reg (
      .en(in_fire), .pop(out_fire), .valid(out_valid), .*
    );
  endmodule
