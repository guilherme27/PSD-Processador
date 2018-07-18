module proc (DIN, Resetn, Clock, Run, Done, BusWires);
	input [8:0] DIN;
	input Resetn, Clock, Run;
	output Done;
	output [8:0] BusWires;

	//Definição de parametros para melhor controle dos bits
	parameter T0 = 2'b00, T1 = 2'b01, T2 = 2'b10, T3 = 2'b11,
		MV = 2'b00, MVI = 2'b01, ADD = 2'b10, SUB = 2'b11;
		DINout_Ctrl = 4'b1000, Gout_Ctrl = 4'b1001, DefaultMulti = 4'b1111;

	//Fios para:	WRX = saída dos registradores de 0 a 7
	wire [8:0] WR0, [8:0] WR1, [8:0] WR2, [8:0] WR3,
		 [8:0] WR4, [8:0] WR5, [8:0] WR6, [8:0] WR7;

	/*Barramentos para controle de dados do processador:
		BusFSMReg = controle de acesso aos registradores
		BusFSMMulti = controle de acesso ao multiplexador
		BusAout = saída do registrador A
		BusGout = saída do registrador G
		BusIRout = saída do registrador BusIRout
		BusUout = saída do registrador U
	*/
	wire [7:0] BusFSMReg, [3:0] BusFSMMulti, [8:0] BusAout,
		 [8:0] BusGout, [8:0] BusIRout, [8:0] BusUout;

	wire [7:0] WXR, [7:0] WYR;

	wire WAin, WGin, WIRin;

	assign BusAout = Aout;
	assign BusGout = Gout;
	assign BusUout = Uout;
	assign BusIRout = IRout;

	assign WR0 = R0;
	assign WR1 = R1;
	assign WR2 = R2;
	assign WR3 = R3;
	assign WR4 = R4;
	assign WR5 = R5;
	assign WR6 = R6;
	assign WR7 = R7;

	assign WAin = Ain;
	assign WGin = Gin;
	assign WIRin = IRin;

	assign WXR = Xreg;
	assign WYR = Yreg;

	dec3to8 decX (BusIRout[5:3], EnableDec, Xreg);
	dec3to8 decY (BusIRout[2:0], EnableDec, Yreg);

	regn reg_0 (BusWires, BusFSMReg[0], Clock, R0);
	regn reg_1 (BusWires, BusFSMReg[1], Clock, R1);
	regn reg_2 (BusWires, BusFSMReg[2], Clock, R2);
	regn reg_3 (BusWires, BusFSMReg[3], Clock, R3);
	regn reg_4 (BusWires, BusFSMReg[4], Clock, R4);
	regn reg_5 (BusWires, BusFSMReg[5], Clock, R5);
	regn reg_6 (BusWires, BusFSMReg[6], Clock, R6);
	regn reg_7 (BusWires, BusFSMReg[7], Clock, R7);

	regn reg_A (BusWires, WAin, Clock, Aout);
	regn reg_G (BusWires, WGin, Clock, Gout);

	regn reg_IR (BusWires[8:6], IRin, Clock, IRout);

	ula addSub (BusAout, BusWires, BusIRout[8:6], Uout);

	multiplexador multiplex (WR0, WR1, WR2, WR3, WR4, WR5, WR6, WR7,
							 DIN, BusGout, BusFSMMulti, BusWires);

	// Controle das saídas da FSM
	always @(posedge Clock or negedge Resetn or Tstep_Q or BusIRout or WXR or WYR)
		begin
			//. . . especifique os valores iniciais
			if (!resetn)
				begin
					Tstep_Q = T0;
					WIRin = 1'b0;
					WAin = 1'b0;
					WGin = 1'b0;
					BusFSMMulti = DefaultMulti;
					EnableDec = 1'b0;
					Done = 1'b1;
				end

			else
			case (Tstep_Q)
				T0: // Armazene DIN no registrador IR no passo 0
				begin
					if (!Run)
						Tstep_Q = T0;

					else
						Done = 1'b0;
						WIRin = 1'b1;
						EnableDec = 1'b1;
						Tstep_Q = T1;
				end

				T1: // Defina os sinais do passo 1
					begin
						WIRin = 1'b0;
						case (BusIRout[8:6])
							MV:
								BusFSMMulti = BusIRout[2:0];
								BusFSMReg = WXR;
								Done = 1'b1;
								Tstep_Q = T0;

							MVI:
								BusFSMMulti = DINout_Ctrl;
								BusFSMReg = WXR;
								Done = 1'b1;
								Tstep_Q = T0;

							ADD:
								BusFSMMulti = BusIRout[5:3];
								WAin = 1'b1;
								TStep_Q = T2;

							SUB:
								BusFSMMulti = BusIRout[5:3];
								WAin = 1'b1;
								TStep_Q = T2;

						endcase
					end

				T2: // Defina os sinais do passo 2
					case (BusIRout[8:6]) //--------------- I0 e I1 não aparecem pois não terminam de ser execultadas no T1
						ADD:
							BusFSMMulti = BusIRout[2:0];
							Gin = 1'b1;
							TStep_Q = T3;

						SUB:
							BusFSMMulti = BusIRout[2:0];
							Gin = 1'b1;
							TStep_Q = T3;

					endcase

				T3: // Defina os sinais do passo 3
					case (BusIRout[8:6]) //--------------- I0 e I1 não aparecem pois não terminam de ser execultadas no T1
						ADD:
							BusFSMMulti = Gout_Ctrl;
							BusFSMReg = WXR;
							Done = 1'b1;
							Tstep_Q = T0;

						SUB:
							BusFSMMulti = Gout_Ctrl;
							BusFSMReg = WXR;
							Done = 1'b1;
							Tstep_Q = T0;

					endcase
				default:
					Tstep_Q = T0;
			endcase
		end
endmodule // proc

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

module ula(a, b, sel, Q);
	parameter n = 9
	input [n-1:0] a, b;
	input [2:0] sel;

	output reg [n-1:0] Q;

	always @(a or b or sel) begin
		case(sel)
			3'b010 : Q = a + b; //add
			3'b011 : Q = a - b; //sub
			default : Q = b;
		endcase
	end
endmodule

module multiplexador (R0, R1, R2, R3, R4, R5, R6, R7, DIN, G, CTRL, Q);
	input [8:0]R0, [8:0]R1, [8:0]R2, [8:0]R3, [8:0]R4, [8:0]R5,
		  [8:0]R6, [8:0]R7, [8:0]DIN, [8:0]G, [3:0]CTRL;

	output [8:0]Q;

	always @(*)
		begin
			case (CTRL)
				4'd0: Q = R0;
				4'd1: Q = R1;
				4'd2: Q = R2;
				4'd3: Q = R3;
				4'd4: Q = R4;
				4'd5: Q = R5;
				4'd6: Q = R6;
				4'd7: Q = R7;
				4'd8: Q = DIN;
				4'd9: Q = G;

				default: Q = 9'b0;
			endcase
		end


endmodule // multiplexador
