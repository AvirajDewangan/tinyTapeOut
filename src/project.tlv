\m5_TLV_version 1d: tl-x.org
\m5
   use(m5-1.0)
   
   
   // ########################################################
   // #                                                      #
   // #  Empty template for Tiny Tapeout Makerchip Projects  #
   // #                                                      #
   // ########################################################
   
   // ========
   // Settings
   // ========
   
   //-------------------------------------------------------
   // Build Target Configuration
   //
   var(my_design, tt_um_example)   /// The name of your top-level TT module, to match your info.yml.
   var(target, ASIC)   /// Note, the FPGA CI flow will set this to FPGA.
   //-------------------------------------------------------
   
   var(in_fpga, 1)   /// 1 to include the demo board. (Note: Logic will be under /fpga_pins/fpga.)
   var(debounce_inputs, 0)         /// 1: Provide synchronization and debouncing on all input signals.
                                   /// 0: Don't provide synchronization and debouncing.
                                   /// m5_if_defined_as(MAKERCHIP, 1, 0, 1): Debounce unless in Makerchip.
   
   // ======================
   // Computed From Settings
   // ======================
   
   // If debouncing, a user's module is within a wrapper, so it has a different name.
   var(user_module_name, m5_if(m5_debounce_inputs, my_design, m5_my_design))
   var(debounce_cnt, m5_if_defined_as(MAKERCHIP, 1, 8'h03, 8'hff))

\SV
   // Include Tiny Tapeout Lab.
   m4_include_lib(['https:/']['/raw.githubusercontent.com/os-fpga/Virtual-FPGA-Lab/5744600215af09224b7235479be84c30c6e50cb7/tlv_lib/tiny_tapeout_lib.tlv'])


\TLV my_design()
   
   
   
   // ==================
   // |                |
   // | YOUR CODE HERE |
   // |                |
   // ==================
   
   // Note that pipesignals assigned here can be found under /fpga_pins/fpga.
   
   
   
   
   // Connect Tiny Tapeout outputs. Note that uio_ outputs are not available in the Tiny-Tapeout-3-based FPGA boards.
   *uo_out = 8'b0;
   m5_if_neq(m5_target, FPGA, ['*uio_out = 8'b0;'])
   m5_if_neq(m5_target, FPGA, ['*uio_oe = 8'b0;'])

// Set up the Tiny Tapeout lab environment.
\TLV tt_lab()
   // Connect Tiny Tapeout I/Os to Virtual FPGA Lab.
   m5+tt_connections()
   // Instantiate the Virtual FPGA Lab.
   m5+board(/top, /fpga, 7, $, , my_design)
   // Label the switch inputs [0..7] (1..8 on the physical switch panel) (top-to-bottom).
   m5+tt_input_labels_viz(['"UNUSED", "UNUSED", "UNUSED", "UNUSED", "UNUSED", "UNUSED", "UNUSED", "UNUSED"'])

\SV

// ================================================
// A simple Makerchip Verilog test bench driving random stimulus.
// Modify the module contents to your needs.
// ================================================

module top(input logic clk, input logic reset, input logic [31:0] cyc_cnt, output logic passed, output logic failed);
   // Tiny tapeout I/O signals.
   logic [7:0] ui_in, uo_out;
   m5_if_neq(m5_target, FPGA, ['logic [7:0] uio_in, uio_out, uio_oe;'])
   logic [31:0] r;  // a random value
   
   always @(posedge clk) r <= m5_if_defined_as(MAKERCHIP, 1, ['$urandom()'], ['0']);
   assign ui_in = r[7:0]; 
   m5_if_neq(m5_target, FPGA, ['assign uio_in = 8'b0;'])
   logic ena = 1'b0;
   logic rst_n = ! reset;
   
   /*
   // Or, to provide specific inputs at specific times (as for lab C-TB) ...
   // BE SURE TO COMMENT THE ASSIGNMENT OF INPUTS ABOVE.
   // BE SURE TO DRIVE THESE ON THE B-PHASE OF THE CLOCK (ODD STEPS).
   // Driving on the rising clock edge creates a race with the clock that has unpredictable simulation behavior.
   initial begin
      #1  // Drive inputs on the B-phase.
         ui_in = 8'h0;
      #10 // Step 5 cycles, past reset.
         ui_in = 8'hFF;
      // ...etc.
   end
   */

   // Instantiate the Tiny Tapeout module.
   m5_user_module_name tt(.*);
   
   assign passed = top.cyc_cnt > 80;
   assign failed = 1'b0;
endmodule


// Provide a wrapper module to debounce input signals if requested.
m5_if(m5_debounce_inputs, ['m5_tt_top(m5_my_design)'])
\SV

//`timescale  1ns/1ps

//---------------------------------------------------------controller---------------------------------------------------

   module Controller (
       input clk,
       input reset,
       input start,
       input low,
       input med,
       input hig,
       output reg heating,
       output reg spinning, 
       output reg pouring,
       output reg waiting 
   );

   /*
   reset is also used as stop here 
   */

   //-------------------------------------------------------state variable-------------------------------------------------

       reg [2:0] state_var;                //holds the state values
       reg [2:0] next_state_var;           //holds the next state values 

       always @(next_state_var) begin
           state_var <= next_state_var;    //transfers the state values for the next state
       end

   //--------------------------------------------------------state values--------------------------------------------------

       //these variables holds the value of the state variable for comparison

       parameter program_selection = 3'd1;             
       parameter temperature_selection = 3'd2;
       parameter water_level_selection = 3'd3;
       parameter duration = 3'd4;
       parameter wash = 3'd5;
       parameter rinse = 3'd6;
       parameter dry = 3'd7;

   //--------------------------------------------------------parameters---------------------------------------------------

       parameter med_heating = 12'd35; //enter med heating time => depends on temp     => 2.5 mins
       parameter hig_heating = 12'd70; //enter hig heating time => depends on temp     => 5 mins
       parameter low_pouring = 12'd28; //enter low pouring time => depends on level    => 2 mins
       parameter med_pouring = 12'd42; //enter med pouring time => depends on level    => 3 mins
       parameter hig_pouring = 12'd56; //enter hig pouring time => depends on level    => 4 mins
       /*
           proper time assignment is left that should be done here 
           low timer => 5 mins 
           med timer => 15 mins 
           hig timer => 30 mins
       */
       parameter low_timer = 12'd70; //enter time for low duration wash => depends on timer
       parameter med_timer = 12'd210; //enter time for low duration wash => depends on timer
       parameter hig_timer = 12'd420; //enter time for low duration wash => depends on timer


   //-------------------------------------------------------input_for_states-----------------------------------------------

       reg [1:0] timer;          //stores time signal

       reg [1:0] Program;          //stores mode signal

       reg [1:0] temp;             //stores temperature signal

       reg [1:0] level;            //stores water level signal

       reg [1:0] counter_status;   //stores counter status

       //reg count_done;             //doing nothing important 

       reg rinse_status;           //provide rinse status for counter

       reg dry_status;             //provide drying status for counter

       reg [11:0] max_count;

   //----------------------------------------------------------controller--------------------------------------------------

       //always @(posedge clk or posedge reset or posedge start) begin
       always @(posedge clk) begin
           //synthesizable INITIAL BLOCK
           if(reset)
               //when reset is high the value of all the registers changes to zero (DEFAULT VALUE)
               begin
                   timer <= 2'b0;
                   Program <= 2'b0;
                   temp <= 2'b0;
                   level <= 2'b0;
                   //counter_status <= 2'b0;
                   next_state_var <= 3'b0;
                   //count_done <= 1'b0;
                   //rinse_status <= 1'b0;
                   //dry_status <= 1'b0;
                   //max_count <= 12'b0;

                   //assigning output vairables to zero during reset

                   //heating <= 1'b0;
                   waiting <= 1'b0;
                   //spinning <= 1'b0;
                   //pouring <= 1'b0;
               end
           else if(start)
               //when start signal is applied the value of the state variable increases by one
               begin
                   next_state_var <= 3'b01;
               end
           else 
               begin
                   case (state_var)   

                       //Program selection stage

                       program_selection:
                           begin 
                               waiting <= 1'b1;
                               if(low)
                                   begin
                                       Program <= 2'd1;
                                   end
                               else if(med)
                                   begin
                                       Program <= 2'd2;
                                   end
                               else if(hig)
                                   begin
                                       Program <= 2'd3;
                                   end
                               else if(next_state_var == temperature_selection |(Program != 2'b0 && (!low & !med & !hig)))
                                   begin
                                       next_state_var <= temperature_selection;
                                       waiting <= 1'b0;
                                   end
                               else
                                   next_state_var <= program_selection;
                           end

                       //temperature selection stage 

                       temperature_selection:
                           begin
                               waiting <= 1'b1;
                               if(low)
                                   begin
                                       temp <= 2'd1;
                                   end
                               else if(med)
                                   begin
                                       temp <= 2'd2;
                                   end
                               else if(hig)
                                   begin
                                       temp <= 2'd3;
                                   end
                               else if(next_state_var == water_level_selection |(temp != 2'b0 && (!low & !med & !hig)))
                                   begin
                                       next_state_var <= water_level_selection;
                                       waiting <= 1'b0;
                                   end
                               else 
                                   next_state_var <= temperature_selection;
                           end

                       //water level selection stage 

                       water_level_selection:
                           begin
                               waiting <= 1'b1;
                               if(low)
                                   begin
                                       level <= 2'd1;
                                   end
                               else if(med)
                                   begin
                                       level <= 2'd2;
                                   end
                               else if(hig)
                                   begin
                                       level <= 2'd3;
                                   end
                               else if(next_state_var == duration |(level != 2'b0 && (!low & !med & !hig)))
                                   begin
                                       next_state_var <= duration;
                                       waiting <= 1'b0;
                                   end
                               else 
                                   next_state_var <= water_level_selection;
                           end

                       //duration selecion stage (updating timer value)

                       duration:
                           begin
                               waiting <= 1'b1;
                               if(low)
                                   begin
                                       timer <= 2'd1;
                                   end
                               else if(med)
                                   begin
                                       timer <= 2'd2;
                                   end
                               else if(hig)
                                   begin
                                       timer <= 2'd3;
                                   end
                               else if(next_state_var == wash |(timer != 2'b0 && (!low & !med & !hig)))
                                   begin
                                       next_state_var <= wash;
                                       //count_done <= 1'b0;
                                       waiting <= 1'b0;
                                   end
                               else 
                                   next_state_var <= duration;
                           end
                       wash:
                           begin
                               //spinning <= 1'b1;
                               if(counter_status == 2'd2)
                                   begin
                                       next_state_var <= rinse;
                                   end
                               else
                                   begin
                                       next_state_var <= wash;
                                   end
                           end
                       rinse:
                           begin
                               if(counter_status == 2'd2)
                                   begin
                                       next_state_var <= dry;
                                   end
                               else
                                   begin
                                       next_state_var <= rinse;
                                   end
                           end
                       dry:
                           begin
                               if(counter_status == 2'd2)
                                   begin
                                       next_state_var <= 3'dx;
                                       timer <= 2'b0;
                                       Program <= 2'b0;
                                       temp <= 2'b0;
                                       level <= 2'b0;
                                       counter_status <= 2'b0;
                                       next_state_var <= 3'b0;
                                       //count_done = 1'b0;
                                       //spinning <= 1'b0;
                                   end
                               else
                                   begin
                                       next_state_var <= dry;
                                   end
                           end
                           //default
                       default: 
                           //this state can be used for pause as well 
                           next_state_var <= next_state_var;

                   endcase
               end
       end

   //------------------------------------------------------------counter----------------------------------------------------


       //set appropriate counter values: 
       reg [11:0] counter1 ;
       reg [31:0] counter2 ;

       //always @(posedge clk or posedge reset) begin
       always @(posedge clk) begin
           if(state_var == 3'b0)
              spinning <= 1'b0;
           else 
              spinning <= spinning;
           if(reset)
           begin
               counter1 = 12'b0;
               counter2 <= 32'b0;
               max_count <= 12'b0;
               pouring <= 1'b0;
               heating <= 1'b0;
               spinning <= 1'b0;
               rinse_status <= 1'b0;
               dry_status <= 1'b0;
               counter_status <= 2'b0;
           end
           else
               begin
                   case (state_var)
                       wash:
                           begin
                               if(timer == 2'd1 && counter_status == 2'b0)
                                   begin
                                       counter1 = low_timer; 
                                       if((temp==2'd1)&&(level==2'd1))
                                           counter1 = counter1 + low_pouring;
                                       else if((temp==2'd1)&&(level==2'd2))
                                           counter1 = counter1 + med_pouring;
                                       else if((temp==2'd1)&&(level==2'd3))
                                           counter1 = counter1 + hig_pouring;
                                       else if((temp==2'd2)&&(level==2'd1))
                                           counter1 = counter1 + med_heating + low_pouring;
                                       else if((temp==2'd2)&&(level==2'd2))
                                           counter1 = counter1 + med_heating + med_pouring;
                                       else if((temp==2'd2)&&(level==2'd3))
                                           counter1 = counter1 + med_heating + hig_pouring;
                                       else if((temp==2'd3)&&(level==2'd1))
                                           counter1 = counter1 + hig_heating + low_pouring;
                                       else if((temp==2'd3)&&(level==2'd2))
                                           counter1 = counter1 + hig_heating + med_pouring;
                                       else if((temp==2'd3)&&(level==2'd3))
                                           counter1 = counter1 + hig_heating + hig_pouring;
                                       else
                                           counter1 = counter1;

                                       max_count <= counter1;

                                   end
                               else if(timer == 2'd2 && counter_status == 2'b0)
                                   begin
                                       counter1 = med_timer;
                                       if((temp==2'd1)&&(level==2'd1))
                                           counter1 = counter1 + low_pouring;
                                       else if((temp==2'd1)&&(level==2'd2))
                                           counter1 = counter1 + med_pouring;
                                       else if((temp==2'd1)&&(level==2'd3))
                                           counter1 = counter1 + hig_pouring;
                                       else if((temp==2'd2)&&(level==2'd1))
                                           counter1 = counter1 + med_heating + low_pouring;
                                       else if((temp==2'd2)&&(level==2'd2))
                                           counter1 = counter1 + med_heating + med_pouring;
                                       else if((temp==2'd2)&&(level==2'd3))
                                           counter1 = counter1 + med_heating + hig_pouring;
                                       else if((temp==2'd3)&&(level==2'd1))
                                           counter1 = counter1 + hig_heating + low_pouring;
                                       else if((temp==2'd3)&&(level==2'd2))
                                           counter1 = counter1 + hig_heating + med_pouring;
                                       else if((temp==2'd3)&&(level==2'd3))
                                           counter1 = counter1 + hig_heating + hig_pouring;
                                       else
                                           counter1 = counter1;

                                       max_count <= counter1;

                                   end
                               else if(timer == 2'd3 && counter_status == 2'b0)
                                   begin
                                       counter1 = hig_timer; 
                                       if((temp==2'd1)&&(level==2'd1))
                                           counter1 = counter1 + low_pouring;
                                       else if((temp==2'd1)&&(level==2'd2))
                                           counter1 = counter1 + med_pouring;
                                       else if((temp==2'd1)&&(level==2'd3))
                                           counter1 = counter1 + hig_pouring;
                                       else if((temp==2'd2)&&(level==2'd1))
                                           counter1 = counter1 + med_heating + low_pouring;
                                       else if((temp==2'd2)&&(level==2'd2))
                                           counter1 = counter1 + med_heating + med_pouring;
                                       else if((temp==2'd2)&&(level==2'd3))
                                           counter1 = counter1 + med_heating + hig_pouring;
                                       else if((temp==2'd3)&&(level==2'd1))
                                           counter1 = counter1 + hig_heating + low_pouring;
                                       else if((temp==2'd3)&&(level==2'd2))
                                           counter1 = counter1 + hig_heating + med_pouring;
                                       else if((temp==2'd3)&&(level==2'd3))
                                           counter1 = counter1 + hig_heating + hig_pouring;
                                       else
                                           counter1 = counter1;

                                       max_count <= counter1;

                                   end
                               else if((counter1 != 12'b0) && (counter2 == 32'b0))
                                   begin
                                       counter1 = counter1 - 12'b1;
                                   end
                               else
                                   begin
                                       counter1 = counter1;
                                       //code the conditions for heating and pouring here 

                                       if(temp==2'd1 && level==2'd1)
                                           begin
                                               if((max_count - counter1) <=  low_pouring )
                                                   begin
                                                       pouring <= 1'b1;
                                                       spinning <= 1'b0;
                                                       //heating <= 1'b0;
                                                   end
                                               else
                                                   begin
                                                       pouring <= 1'b0;
                                                       spinning <= 1'b1;
                                                       //heating <= 1'b0;
                                                   end
                                           end
                                       else if(temp==2'd1 && level==2'd2)
                                           begin
                                               if((max_count - counter1) <= med_pouring)
                                                   begin
                                                       pouring <= 1'b1;
                                                       spinning <= 1'b0;
                                                       //heating <= 1'b0;
                                                   end
                                               else
                                                   begin
                                                       pouring <= 1'b0;
                                                       spinning <= 1'b1;
                                                       //heating <= 1'b0;
                                                   end
                                           end
                                       else if(temp==2'd1 && level==2'd3)
                                           begin
                                               if((max_count - counter1) <= hig_pouring )
                                                   begin
                                                       pouring <= 1'b1;
                                                       spinning <= 1'b0;
                                                       //heating <= 1'b0;
                                                   end
                                               else
                                                   begin
                                                       pouring <= 1'b0;
                                                       spinning <= 1'b1;
                                                       //heating <= 1'b0;
                                                   end
                                           end
                                       else if(temp==2'd2 && level==2'd1)
                                           begin
                                               if((max_count - counter1) <= med_heating )
                                                   begin
                                                       heating <= 1'b1;
                                                       spinning <= 1'b0;
                                                       pouring <= 1'b0;
                                                   end
                                               else if((max_count - counter1) <= (med_heating + low_pouring) )
                                                   begin
                                                       heating <= 1'b0;
                                                       pouring <= 1'b1;
                                                       spinning <= 1'b0;
                                                   end
                                               else
                                                   begin
                                                       pouring <= 1'b0;
                                                       spinning <= 1'b1;
                                                       heating <= 1'b0;
                                                   end
                                           end
                                       else if(temp==2'd2 && level==2'd2)
                                           begin
                                               if((max_count - counter1) <= med_heating )
                                                   begin
                                                       heating <= 1'b1;
                                                       spinning <= 1'b0;
                                                       pouring <= 1'b0;
                                                   end
                                               else if((max_count - counter1) <= (med_heating + med_pouring))
                                                   begin
                                                       heating <= 1'b0;
                                                       pouring <= 1'b1;
                                                       spinning <= 1'b0;
                                                   end
                                               else
                                                   begin
                                                       pouring <= 1'b0;
                                                       spinning <= 1'b1;
                                                       heating <= 1'b0;
                                                   end
                                           end
                                       else if(temp==2'd2 && level==2'd3)
                                           begin
                                               if((max_count - counter1) <= med_heating )
                                                   begin
                                                       heating <= 1'b1;
                                                       spinning <= 1'b0;
                                                       pouring <= 1'b0;
                                                   end
                                               else if((max_count - counter1) <= (med_heating + hig_pouring) )
                                                   begin
                                                       heating <= 1'b0;
                                                       pouring <= 1'b1;
                                                       spinning <= 1'b0;
                                                   end
                                               else
                                                   begin
                                                       pouring <= 1'b0;
                                                       spinning <= 1'b1;
                                                       heating <= 1'b0;
                                                   end
                                           end
                                       else if(temp==2'd3 && level==2'd1)
                                           begin
                                               if((max_count - counter1) <= hig_heating )
                                                   begin
                                                       heating <= 1'b1;
                                                       spinning <= 1'b0;
                                                       pouring <= 1'b0;
                                                   end
                                               else if((max_count - counter1) <= (hig_heating + low_pouring) )
                                                   begin
                                                       heating <= 1'b0;
                                                       pouring <= 1'b1;
                                                       spinning <= 1'b0;
                                                   end
                                               else
                                                   begin
                                                       pouring <= 1'b0;
                                                       spinning <= 1'b1;
                                                       heating <= 1'b0;
                                                   end
                                           end
                                       else if(temp==2'd3 && level==2'd2)
                                           begin
                                               if((max_count - counter1) <= hig_heating)
                                                   begin
                                                       heating <= 1'b1;
                                                       spinning <= 1'b0;
                                                       pouring <= 1'b0;
                                                   end
                                               else if((max_count - counter1) <= (hig_heating + med_pouring))
                                                   begin
                                                       heating <= 1'b0;
                                                       pouring <= 1'b1;
                                                       spinning <= 1'b0;
                                                   end
                                               else
                                                   begin
                                                       pouring <= 1'b0;
                                                       spinning <= 1'b1;
                                                       heating <= 1'b0;
                                                   end
                                           end
                                       else if(temp==2'd3 && level==2'd3)
                                           begin
                                               if((max_count - counter1) <= hig_heating)
                                                   begin
                                                       heating <= 1'b1;
                                                       spinning <= 1'b0;
                                                       pouring <= 1'b0;
                                                   end
                                               else if((max_count - counter1) <= (hig_heating + hig_pouring))
                                                   begin
                                                       heating <= 1'b0;
                                                       pouring <= 1'b1;
                                                       spinning <= 1'b0;
                                                   end
                                               else
                                                   begin
                                                       pouring <= 1'b0;
                                                       spinning <= 1'b1;
                                                       heating <= 1'b0;
                                                   end
                                           end
                                       else
                                           begin
                                               pouring <= 1'b0;
                                               heating <= 1'b0;
                                               spinning <= 1'b0;
                                           end
                                   end
                           end
                       rinse:
                           begin
                               if((counter1 == 12'b0) && (!rinse_status))
                                   begin
                                       counter1 = 12'd70;
                                       rinse_status <= 1'b1;
                                   end
                               else if((counter1 != 12'b0) && (counter2 == 32'b0))
                                   counter1 = counter1 - 12'b1;
                               else 
                                   counter1 = counter1;
                           end
                       dry:
                           begin
                               if((counter1 == 12'b0) && (!dry_status))
                                   begin
                                       counter1 = 12'd70;
                                       dry_status <= 1'b1;
                                   end
                               else if((counter1 != 12'b0) && (counter2 == 32'b0))
                                   counter1 = counter1 - 12'b1;
                               else 
                                   counter1 = counter1;
                           end
                       default:
                           counter1 = counter1;
                   endcase

                   if((counter1 != 12'b0)  && (counter2 != 32'b0))
                       counter2 <= counter2 - 32'b1;
                   else if((counter1 != 12'b0) && (counter2 == 32'b0))
                       counter2 <= 32'hffffffff;
                   else 
                       counter2 <= 32'hffffffff;

                   //COUNTER TERMINATING CONDITIONS

                   if((counter1 == 12'b0) && ((state_var == wash) | (state_var == rinse) | (state_var == dry)) && (counter_status == 2'd1))
                       counter_status <= 2'd2;
                   else if((state_var == wash) | (state_var == rinse) | (state_var == dry))
                       counter_status <= 2'b1;
                   else
                       counter_status <= 2'b0;
               end

       end

       //reseting the state variable

       always @(state_var) begin

           counter_status <= 2'b0;

       end

   endmodule

// =======================
// The Tiny Tapeout module
// =======================

module m5_user_module_name (
    input  wire [7:0] ui_in,    // Dedicated inputs - connected to the input switches
    output wire [7:0] uo_out,   // Dedicated outputs - connected to the 7 segment display
    m5_if_eq(m5_target, FPGA, ['/']['*'])   // The FPGA is based on TinyTapeout 3 which has no bidirectional I/Os (vs. TT6 for the ASIC).
    input  wire [7:0] uio_in,   // IOs: Bidirectional Input path
    output wire [7:0] uio_out,  // IOs: Bidirectional Output path
    output wire [7:0] uio_oe,   // IOs: Bidirectional Enable path (active high: 0=input, 1=output)
    m5_if_eq(m5_target, FPGA, ['*']['/'])
    input  wire       ena,      // will go high when the design is enabled
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);
   wire reset = ! rst_n;

   // List all potentially-unused inputs to prevent warnings
   wire _unused = &{ena, clk, rst_n, 1'b0};

\TLV
   /* verilator lint_off UNOPTFLAT */
   m5_if(m5_in_fpga, ['m5+tt_lab()'], ['m5+my_design()'])

\SV_plus
   
   // ==========================================
   // If you are using Verilog for your design,
   // your Verilog logic goes here.
   // Note, output assignments are in my_design.
   // ==========================================
   

   reg waiting, heating, spinning, pouring;
   wire start = ui_in[0], low = ui_in[1], med = ui_in[2], hig = ui_in[3];
   assign uo_out = {4'b0, waiting, heating, spinning, pouring};
   Controller Controller(.*);
\SV
endmodule
