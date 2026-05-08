/* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -*/
/* Custom Music Player Peripheral                                             */
/* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -*/

module User_Peripheral (input  wire        clk,           /* System clock     */
                        input  wire        reset,         /* System reset     */
                        input  wire        cs_i,          /* Device select    */
                        input  wire        read_i,        /* Bus read select  */
                        input  wire  [1:0] size_i,        /* Transfer size    */
                        input  wire        write_i,       /* Bus write select */
                        input  wire  [1:0] mode_i,        /* Privilege mode   */
                        input  wire [31:0] address_i,     /* Processor address*/
                        output wire        stall_o,       /* Bus wait output  */
                        output wire  [2:0] abort_o,       /* Bus error        */
                        input  wire [31:0] data_in,       /* Store data bus   */
                        output reg  [31:0] data_out,      /* Load data bus    */

                        input  wire [31:0] port_in,       /*Connections towards 
                                                          /* pin_fn      */
                        output wire [31:0] port_out, 
                        output wire [31:0] port_direction,/* 1nput or 0utput  */
                        output wire  [7:0] LED_o,         /* Connections towards
                                                          /* PCB LEDs        */
                                                           
                        output wire  [7:0] LCD_data_o,    /* Outputs to LCD   */
                        input  wire  [7:0] LCD_data_i,    /* Inputs from LCD  */
                        output wire        LCD_RW_o,      /* Read Not write   */
                        output wire        LCD_RS_o,      /* LCD Reg select   */
                        output wire        LCD_E_o,       /* LCD Enable       */
                        output wire        LCD_BL_o,      /* LCD Backlight,   */
                                                          /* Active high      */
                                                          
                        input  wire  [3:0] switch_i,      /* PCB switch states*/
                        output wire  [3:0] irq_o);        /*Interrupt requests*/


// ----------------------------------------------------------------------------
// INTERNAL REGISTERS (The hardware variables)
// ----------------------------------------------------------------------------
reg  [15:0] addr_latch;     // Remembers which address the CPU asked for

reg  [31:0] pitch_period;   // Address 0x0: Stores how many clock ticks make a note
reg  [31:0] led_data_reg;   // Address 0x4: Stores data to show on LEDs if we want

reg  [31:0] counter;        // Counts from 0 up to 'pitch_period'
reg         buzzer_state;   // Flips between 0 and 1 to create the sound wave


// ----------------------------------------------------------------------------
// BUS LOGIC (Connecting software writes to our registers)
// ----------------------------------------------------------------------------

assign stall_o =    cs_i   && 1'b0;        
assign abort_o = {3{cs_i}} && 3'h0;      

// Every time the clock pulses, if the CPU is reading from us, remember the address
always @ (posedge clk)                         
    if (cs_i && read_i) addr_latch <= address_i[7:0];    

// Handling WRITES: When the CPU Store Word (sw)
always @ (posedge clk) begin
    if (reset) begin
        pitch_period <= 32'h0;
        led_data_reg <= 32'h0;
    end
    else if (cs_i && write_i) begin
        // We look at bits [3:2] of the address to choose which register to update.
        // address 0x0 (binary ...0000) -> [3:2] is 00
        // address 0x4 (binary ...0100) -> [3:2] is 01
        case (address_i[3:2])                      
            2'b00: pitch_period <= data_in; // Update the sound pitch
            2'b01: led_data_reg <= data_in; // Update the LED display data
        endcase
    end
end

// Handling READS: When the CPU Load Word (lw)
always @ (*) begin                                     
    case (addr_latch[3:2])                
        2'b00:   data_out = pitch_period;
        2'b01:   data_out = led_data_reg;
        default: data_out = 32'h0;
    endcase
end


// ----------------------------------------------------------------------------
// THE SOUND ENGINE (Turning the number into a physical vibration)
// ----------------------------------------------------------------------------
always @(posedge clk) begin
    if (reset || pitch_period == 0) begin
        // If reset is hit or pitch is 0, stop counting and stay silent
        counter <= 0;
        buzzer_state <= 0;
    end 
    else if (counter >= pitch_period - 1) begin
        // When we reach the target number, reset the counter and FLIP the signal
        counter <= 0;
        buzzer_state <= ~buzzer_state; 
    end 
    else begin
        // Otherwise, just keep counting up
        counter <= counter + 1;
    end
end


// ----------------------------------------------------------------------------
// PIN ROUTING (Connecting the logic to the physical board)
// ----------------------------------------------------------------------------

// Drive Pins 6 and 7 of the expansion port.
// We use ~ (NOT) on the second one so they are in 'Antiphase'.
// While pin 6 pushes, pin 7 pulls. This makes the buzzer much louder!
assign port_out = {24'h0, buzzer_state, ~buzzer_state, 6'h0}; 

// Set pins 6 and 7 to be OUTPUTS (0) and everything else to be INPUTS (1).
// In Hex, 3F is 0011_1111 (The two zeros are our buzzer pins).
assign port_direction = 32'hFFFF_FF3F;        

// Output the 'led_data_reg' to the physical green LEDs on the board
assign LED_o = led_data_reg[7:0]; 

// Safe defaults for other board features so they don't behave randomly
assign irq_o      = 4'b0000;
assign LCD_data_o = 8'h00;
assign LCD_RW_o   = 1'b1;        
assign LCD_RS_o   = 1'b0;
assign LCD_E_o    = 1'b0;
assign LCD_BL_o   = 1'b0;

endmodule