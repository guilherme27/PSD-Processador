module Proc (DIN, Resetn, Clock, Run, Done, BusWires);
	/* Este módulo especifica o circuito de um processador simples, capaz de realizar quatro operações,
	a saber: move, move immediate, add e sub.
	*/
	input [8:0] DIN; 				// Entrada de instruções e de constantes (iiixxxyyy).
	input Resetn, Clock, Run; 	// Sinais de reset, pulso e execução.
	output reg Done; 				// Sinal que representa finalização.
	output [8:0] BusWires; 		// Sinais de saída e barramento principal.

	// Definição de parametros para melhor controle dos bits.
	parameter T0 = 3'b000,				// Tempo 0.
				 T1_1 = 3'b001,				// Tempo 1 (MV).
				 T1_2 = 3'b010,				// Tempo 1 (MVI).
				 T1_3 = 3'b011,				// Tempo 1 (ADD e SUB).
				 T2 = 3'b100,					// Tempo 2 (ADD e SUB)
				 T3 = 3'b101,					// Tempo 3 (ADD e SUB)
				 MV = 3'b000,					// Opcode da instrução move.
				 MVI = 3'b001,				// Opcode da instrução move immediate.
				 ADD = 3'b010,				// Opcode da instrução add.
				 SUB = 3'b011,				// Opcode da instrução sub.
				 DINMuxOut = 4'b1000,		// Usado para setar DIN na saída do mux.
				 GMuxOut = 4'b1001,			// Usado para setar G na saída do mux.
				 DefaultMux = 4'b1111;		// Usado para setar a saída do mux para zero.

	// Variável da máquina de estados.
	reg [2:0] Tstep_Q;

	// Sinais de controle de escrita de todos os registradores e do decodificador.
	reg enableIR, enableA, enableG, enableDec; 	// Habilita IR, A, G e decodificador.
	reg [7:0] enableR; 									// Habilita registradores de R0 a R7 (não confundir com enableRegX)

	// Fio que recebe o endereço do registrador a ser escrito (não confundir com enableR)(dúvidas nessa parte? pergunte a Alfredo)
	wire [7:0] enableRegX;

	// Fio de entrada para o registrador G.
	wire [8:0] inputG;

	// Fios de ligação entre os registradores e o MUX.
	wire [7:0] outputR [8:0];		// Fios de saída dos registradores R7 a R0. (dúvidas nessa parte? pergunte a Alfredo)
	wire [8:0] outputIR; 			// Fios de saída do registrador IR.
	wire [8:0] outputA; 				// Fios de saída do registrador A.
	wire [8:0] outputG; 				// Fios de saída do registrador G.

	// Sinal de controle do multiplexador.
	reg [3:0] ctrlMux;

	// Sinal de controle da ULA.
	reg [2:0] opcodeALU;

	// Instanciação dos registradores específicos.
	Reg IR (.En(enableIR), .Clk(Clock), .In(DIN), .Out(outputIR)); 		// Registador de instruções.
	Reg A (.En(enableA), .Clk(Clock), .In(BusWires), .Out(outputA)); 		// Registrador da palavra A da ULA.
	Reg G (.En(enableG), .Clk(Clock), .In(inputG), .Out(outputG)); 		// Registrador de saída da ULA.

	// Intanciação dos registradores gerais (R0 a R7).
	Reg reg_0 (.En(enableR[0]), .Clk(Clock), .In(BusWires), .Out(outputR[0]));
	Reg reg_1 (.En(enableR[1]), .Clk(Clock), .In(BusWires), .Out(outputR[1]));
	Reg reg_2 (.En(enableR[2]), .Clk(Clock), .In(BusWires), .Out(outputR[2]));
	Reg reg_3 (.En(enableR[3]), .Clk(Clock), .In(BusWires), .Out(outputR[3]));
	Reg reg_4 (.En(enableR[4]), .Clk(Clock), .In(BusWires), .Out(outputR[4]));
	Reg reg_5 (.En(enableR[5]), .Clk(Clock), .In(BusWires), .Out(outputR[5]));
	Reg reg_6 (.En(enableR[6]), .Clk(Clock), .In(BusWires), .Out(outputR[6]));
	Reg reg_7 (.En(enableR[7]), .Clk(Clock), .In(BusWires), .Out(outputR[7]));

	// Instanciação do multiplexador.
	Multiplexer multiplexer (.R0(outputR[0]), .R1(outputR[1]), .R2(outputR[2]), .R3(outputR[3]),
							 .R4(outputR[4]), .R5(outputR[5]), .R6(outputR[6]), .R7(outputR[7]),
							 .DIN(DIN), .G(outputG), .Ctrl(ctrlMux), .Out(BusWires));

	// Instanciação da ULA.
	ALU alu (.wordA(outputA), .wordB(BusWires), .Ctrl(opcodeALU), .Out(inputG));

	// Instanciação do decodificador 3 para 8.
	Decoder3x8 addressRX (.En(enableDec), .In(outputIR[5:3]), .Out(enableRegX));

	// Controle da FSM.
	always @(posedge Clock)
		begin
			if(!Resetn)
				begin
					Tstep_Q = T0;
				end
			else
				begin
					case(Tstep_Q)
						T0:
							if(!Run)
								begin
									Tstep_Q = T0;
								end
							else
								begin
									if(outputIR[8:6] == MV)
										Tstep_Q = T1_1;
									else if(outputIR[8:6] == MVI)
										Tstep_Q = T1_2;
									else if(outputIR[8:6] == ADD)
										Tstep_Q = T1_3;
									else if(outputIR[8:6] == SUB)
										Tstep_Q = T1_3;
									else
										Tstep_Q = T0;
								end
						T1_1:
							Tstep_Q = T0;
						T1_2:
							Tstep_Q = T0;
						T1_3:
							Tstep_Q = T2;
						T2:
							Tstep_Q = T3;
						T3:
							Tstep_Q = T0;
						default :
							Tstep_Q = T0;
					endcase
				end
		end
		
	// Controle do processador	
	always @(Tstep_Q)
		begin
			if(!Resetn)
				begin
					enableR = 8'b0;
					//enableRegX = 8'b0;
					opcodeALU = 3'b0;
					enableIR = 1'b0;			// Habilita IR
					enableA = 1'b0;			// Desabilita A
					enableG = 1'b0; 			// Desabilita G
					ctrlMux = DefaultMux;	// O mux tem sua saída setada para zero
					enableDec = 1'b0;			// Desabilita o decodificador 3 para 8
					Done = 1'b1;				// Sinaliza que terminou
				end
			else
			/* A FSM se mantém realizando transições entre seus respectivos estados enquanto não há o reset da mesma.
			Quando o reset é colocado em nível lógico baixo, a FSM retorna para o seu estado inicial, e todos os sinais
			referentes ao controle do processador são reiniciados.
			*/

				/* Se não há reset, a FSM prossegue com o processamento normal. Para realização do processamento,
				existem quatro tempos, que são ditos pelos ciclos de clock, a saber: T0, T1, T2 e T3.
				*/
				case (Tstep_Q)
					T0 :
					/* Em T0, a FSM sinaliza, desabilitando o sinal "done", que o processador está em processamento.
					Ao mesmo tempo, armazena o conteúdo de DIN no registrador IR (acionando a entrada do registrador
					de instruções), habilida os decodificadores 3 para 8 (acionando o sinal EnableDec), e transita para o estado T1.
					*/
						begin
							enableA = 1'b0;
							enableG = 1'b0;
							enableR = 8'b0;
							//enableRegX = 8'b0;
							ctrlMux = DefaultMux;
							opcodeALU = 3'b0;
							if(!Run)
								begin
									Done = 1'b1;
									enableIR = 1'b1;			// Habilita IR
								end
							else
								begin
									Done = 1'b0;				// Sinaliza que não está pronto (afinal, ele acabou de começar)
									enableIR = 1'b0;			// Desabilita IR
								end
							enableDec = 1'b1;					// Habilita o decodificador 3 para 8
						end
					T1_1 :
					/* Uma vez estando em T1, a FSM desabilita o recebimento de novas instruções pelo IR através do sinal WIRin,
					e prossegue com o processamento.
					*/
						begin
							enableA = 1'b0;
							enableG = 1'b0;
							enableDec = 1'b1;
							opcodeALU = 3'b0;
							enableIR = 1'b0;
							ctrlMux = outputIR[2:0];		// O mux tem sua saída setada para o endereço de Y
							enableR = enableRegX;			// O decodificador habilita a entrada para o endereço X
							Done = 1'b1;						// Sinaliza que terminou (em seguida, transitaremos de volta para T0)
						end
					T1_2 :
						begin
							enableA = 1'b0;
							enableG = 1'b0;
							enableDec = 1'b1;
							opcodeALU = 3'b0;
							ctrlMux = DINMuxOut;          // O mux tem sua saída setada para a constante DIN
							enableR = enableRegX;         // O decodificador habilita a entrada para o endereço X
							enableIR = 1'b0;
							Done = 1'b1;                  // Sinaliza que terminou (em seguida, transitaremos de volta para T0)
						end
					T1_3 :
					/* Operação add (parte 1 de 3):
					Essa operação, dividida em três partes, realiza a soma de um dado de um determinado registrador
					X com um dado de um determinado registrador Y, e a armazena no registrador X. Nessa primeira parte,
					a FSM habilita a passagem do dado de X para o registrador A, possibilitando que, posteriormente,
					esse dado seja somado com o dado do registrador Y, em T2. Feito isto, a FSM transita para o estado T2.
					X com um dado de um determinado registrador Y, e a armazena no registrador X. Nessa primeira parte,
					a FSM habilita a passagem do dado de X para o registrador A, possibilitando que, posteriormente,
					esse dado seja somado com o dado do registrador Y, em T2. Feito isto, a FSM transita para o estado T2.
					*/
						begin
							Done = 1'b0;
							enableIR = 1'b0;
							enableG = 1'b0;
							enableDec = 1'b1;
							enableR = 8'b0;
							//enableRegX = 8'b0;
							opcodeALU = 3'b0;
							ctrlMux = outputIR[5:3];		// O mux tem sua saída setada para o endereço de X
							enableA = 1'b1;					// Habilita A
						end
					T2 :
					/* Operação add e sub (parte 2 de 3):
					Nesta parte, a FSM habilita a passagem do dado de Y para a ULA, possibilitando que o mesmo seja somado ou
					subtraído com o dado de X já existente no registrador A, e entregue o resultado ao registrador G, que também
					é habilitado nessa etapa. Feito isto, a FSM transita para o estado T3.
					*/												
																	// PELO FATO DE O PROCESSADOR REALIZAR A MESMA COISA EM T2 PARA
						begin										// ADD E SUB, RESOLVI DEIXAR SEM O CASE VERIFICANDO A INSTRUÇÃO
							Done = 1'b0;
							enableIR = 1'b0;
							enableA = 1'b0;
							enableDec = 1'b1;
							enableR = 8'b0;
							//enableRegX = 8'b0;
							ctrlMux = outputIR[2:0];		// O mux tem sua saída setada para o endereço de Y
							enableG = 1'b1;					// Habilita G
							opcodeALU = outputIR[8:6];		// A ULA recebe a instrução solicitada (soma ou subtração)
						end
					T3 :
					/* Operação add e sub (parte 3 de 3):
					Já nessa parte, a FSM habilita a passagem do dado do registrador G pelo multiplexador, possibilitando que
					o mesmo seja armazenado no registrador X, também endereçado nessa parte. Uma vez armazenado, o processador
					sinaliza o término do processamento, habilitando o sinal "done", e transita para o estado inicial (T0),
					para que um novo processamento, que por ventura seja solicitado, seja processado.
					*/												
																	// PELO FATO DE O PROCESSADOR REALIZAR A MESMA COISA EM T2 PARA
						begin										// ADD E SUB, RESOLVI DEIXAR SEM O CASE VERIFICANDO A INSTRUÇÃO
							enableA = 1'b0;
							enableG = 1'b0;
							enableDec = 1'b0;
							opcodeALU = 3'b0;
							ctrlMux = GMuxOut;				// O mux tem sua saída setada para G
							enableR = enableRegX;			// O decodificador habilita a entrada para o endereço X
							Done = 1'b1;						// Sinaliza que terminou
							enableIR = 1'b1;
						end
					default :
						Done = 1'b1;
				endcase
		end
endmodule // Processor

module Reg (En, Clk, In, Out);
	/* Registrador de 9 bits:
	Serve para armazenar os dados manipulados durante todo o processamento.
	Possui um sinal que habilita a ESCRITA de um novo dado (En).
	*/
	input En, Clk;
	input [8:0] In;
	output reg [8:0] Out;
	
	always @(posedge Clk)
		begin
			if (En)
				Out = In;
			else
				Out = Out;
		end
endmodule // Reg

module Multiplexer (R0, R1, R2, R3, R4, R5, R6, R7, DIN, G, Ctrl, Out);
	/* Multiplexador de 9 bits e 10 palavras:
	Através do sinal do controle (Ctrl), seleciona qual registrador (ou a constante)
	deve ter seu dado fornecido à saída (qual registrador (ou constante) deve ser LIDO).
	*/
	input [8:0] R0, R1, R2, R3, R4, R5, R6, R7, DIN, G;
	input [3:0] Ctrl;
	output reg [8:0] Out;

	always @(*)
		begin
			case (Ctrl)
				4'b0000 : Out = R0;
				4'b0001 : Out = R1;
				4'b0010 : Out = R2;
				4'b0011 : Out = R3;
				4'b0100 : Out = R4;
				4'b0101 : Out = R5;
				4'b0110 : Out = R6;
				4'b0111 : Out = R7;
				4'b1000 : Out = DIN;
				4'b1001 : Out = G;
				default : Out = 9'b000000000;
			endcase
		end
endmodule

module ALU (wordA, wordB, Ctrl, Out);
	/* Unidade Lógica e Aritmética:
	Responsável por realizar as sumas e as subtrações do processador.
	Recebe duas palavras de 9 bits e, dependendo do sinal do controle (Ctrl),
	realiza a soma ou a subtração entre as duas palavras.
	*/
	input [8:0] wordA, wordB;
	input [2:0] Ctrl;
	output reg [8:0] Out;

	always @(*)
		begin
			case (Ctrl)
				3'b010 : Out = wordA + wordB;
				3'b011 : Out = wordA - wordB;
				default : Out = wordB;
			endcase
		end
endmodule // ALU

module Decoder3x8 (En, In, Out);
	/* Decodificador de 3 para 8:
	Este módulo é responsável por receber uma palavra de 3 bits, e decodificá-la em uma palavra de 8 bits,
	que servirá para endereçar os registradores de R0 a R7 para serem ESCRITOS. Na palavra de 8 bits, o
	bit setado indica qual registrador deve ter sua escrita habilitada e quais não.
	*/
	input En;
	input [2:0] In;
	output reg [7:0] Out;

	always @(*)
		begin
			if (En)
				case (In)
					3'b000 : Out = 8'b00000001;
					3'b001 : Out = 8'b00000010;
					3'b010 : Out = 8'b00000100;
					3'b011 : Out = 8'b00001000;
					3'b100 : Out = 8'b00010000;
					3'b101 : Out = 8'b00100000;
					3'b110 : Out = 8'b01000000;
					3'b111 : Out = 8'b10000000;
					default : Out = 8'b00000000;
				endcase
			else
				Out = 8'b00000000;
		end
endmodule // Decoder3x8
