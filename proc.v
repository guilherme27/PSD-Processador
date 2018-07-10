module proc (DIN, Resetn, Clock, Run, Done, BusWires);
	input [8:0] DIN;
	input Resetn, Clock, Run;
	output Done;
	output [8:0] BusWires;
	parameter T0 = 2'b00, T1 = 2'b01, T2 = 2'b10, T3 = 2'b11, DINout = 4'b1000, Gout = 4'b1001;
	wire [7:0] BusFSMReg, [3:0] BusFSMMulti, [2:0]ulaControl;
	//. . . declaração de variáveis
	
	/*assign I = IR[8:6];
	assign Rx = IR[5:3];
	assign Ry = IR[2:0];
	*/
	
	dec3to8 decX (IR[5:3], 1'b1, Xreg);
	dec3to8 decY (IR[2:0], 1'b1, Yreg);
	
	regn reg_0 (BusWires, Rin[0], Clock, R0);
	regn reg_1 (BusWires, Rin[1], Clock, R1);
	regn reg_2 (BusWires, Rin[2], Clock, R2);
	regn reg_3 (BusWires, Rin[3], Clock, R3);
	regn reg_4 (BusWires, Rin[4], Clock, R4);
	regn reg_5 (BusWires, Rin[5], Clock, R5);
	regn reg_6 (BusWires, Rin[6], Clock, R6);
	regn reg_7 (BusWires, Rin[7], Clock, R7);
	
	regn reg_A (BusWires, Ain, Clock, Aout);
	regn reg_G (BusWires, Gin, Clock, Gout);
	regn reg_IR (BusWires[8:6], IRin, Clock, IRout);
	
	ula addSub (BusWires, BusWires, DIN, Clock, Uout)

/*	// Controle de estados do FSM
	always @(Tstep_Q, Run, Done) begin
		case (Tstep_Q)
			T0: // Os dados são carregados no IR nesse passo
			if (!Run) 
				Tstep_D = T0;
			else 
				Tstep_D = T1;
			T1:
				//. . .
		endcase
	end*/

	// Controle das saídas da FSM
	always @(posedge Clock or negedge Resetn or Tstep_Q or I or Xreg or Yreg) begin
		//. . . especifique os valores iniciais
		case (Tstep_Q)
			T0: // Armazene DIN no registrador IR no passo 0
			begin
				if (!Run)
					Tstep_Q = T0;
				else
					IRin = 1'b1;
					Tstep_Q = T1;
			end

			T1: // Defina os sinais do passo 1
				case (IR[8:6])
					T0:
						BusFSMMulti = IR[2:0];
						BusFSMReg = Xreg;
						done = 1'b1;
					
					T1:
						BusFSMMulti = DINout;
						BusFSMReg = Xreg;
						done = 1'b1;
					
					T2:
						BusFSMMulti = IR[5:3];
						Ain = 1'b1;
						TStep_Q = T2;
						
					T3:
						BusFSMMulti = IR[5:3];
						Ain = 1'b1;
						TStep_Q = T2;
						
						
				endcase

			T2: // Defina os sinais do passo 2
				case (IR[8:6]) //--------------- I0 e I1 não aparecem pois não terminam de ser execultadas no T1
					T2:
						BusFSMMulti = IR[2:0];
						Gin = 1'b1;
						ulaControl = 3'b010;
						TStep_Q = T3;
						
					T3:
						BusFSMMulti = IR[2:0];
						Gin = 1'b1;
						ulaControl = 3'b011;
						TStep_Q = T3;
						
				endcase

			T3: // Defina os sinais do passo 3
				case (IR[8:6]) //--------------- I0 e I1 não aparecem pois não terminam de ser execultadas no T1
					T2:
						BusFSMMulti = Gout;
						BusFSMReg = Xreg;
						done = 1'b1;
						
					T3:
						BusFSMMulti = Gout;
						BusFSMReg = Xreg;
						done = 1'b1;
						
				endcase
		endcase
	end
endmodule

module dec3to8(W, En, Y);
	input [2:0] W;
	input En;
	output [0:7] Y;

	reg [0:7] Y;

	always @(W or En) begin
		if (En == 1)
			case (W)
				3'b000: Y = 8'b00000001;
				3'b001: Y = 8'b00000010;
				3'b010: Y = 8'b00000100;
				3'b011: Y = 8'b00001000;
				3'b100: Y = 8'b00010000;
				3'b101: Y = 8'b00100000;
				3'b110: Y = 8'b01000000;
				3'b111: Y = 8'b10000000;
			endcase
		else
			Y = 8'b00000000;
	end
endmodule

module regn(R, Rin, Clock, Q);
	parameter n = 9;
	input [n-1:0] R;
	input Rin, Clock;
	output [n-1:0] Q;
	reg [n-1:0] Q;
	 
	always @(posedge Clock)
		if (Rin)
			Q <= R;
endmodule

module ula(a, b, sel, Clock, Q);
	parameter n = 9
	input Clock;
	input [n-1:0] a, b;
	input [2:0] sel;

	output reg [n-1:0] Q;

	always @(posedge Clock) begin
		case(sel)
			3'b010 : Q = a + b; //add
			3'b011 : Q = a - b; //sub
			default : Q = 0;
		endcase
	end
endmodule
