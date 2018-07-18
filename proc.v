module proc (DIN, Resetn, Clock, Run, Done, BusWires);
	/* Este módulo especifica o circuito de um processador simples, capaz de realizar quatro operações,
	a saber: move, move immediate, add e sub.
	*/
	input [8:0] DIN;
	input Resetn, Clock, Run;
	output Done;
	output [8:0] BusWires;

	//Definição de parametros para melhor controle dos bits.
	parameter T0 = 2'b00, T1 = 2'b01, T2 = 2'b10, T3 = 2'b11,
		MV = 2'b00, MVI = 2'b01, ADD = 2'b10, SUB = 2'b11;
		DINout_Ctrl = 4'b1000, Gout_Ctrl = 4'b1001, DefaultMulti = 4'b1111;

	//Fios para saída dos registradores (WRX | 0 ≤ X ≤ 7).
	wire [8:0] WR0, [8:0] WR1, [8:0] WR2, [8:0] WR3,
		 [8:0] WR4, [8:0] WR5, [8:0] WR6, [8:0] WR7;

	/* Barramentos para controle de dados do processador:
	BusFSMReg = controle de acesso a escrita dos registradores
	BusFSMMulti = controle de acesso ao multiplexador
	BusAout = saída do registrador A
	BusGout = saída do registrador G
	BusIRout = saída do registrador IR
	BusUout = saída do registrador U
	*/
	wire [7:0] BusFSMReg, [3:0] BusFSMMulti, [8:0] BusAout,
		 [8:0] BusGout, [8:0] BusIRout, [8:0] BusUout;

	// Fios para controle de acesso a escrita dos registradores X e Y.
	wire [7:0] WXR, [7:0] WYR;

	// Fios para controle de acesso a escrita dos registradores A, G e IR.
	wire WAin, WGin, WIRin;

	// Ligação entre os fios e os barramentos das saídas dos registradores.
	assign BusAout = Aout;
	assign BusGout = Gout;
	assign BusUout = Uout;
	assign BusIRout = IRout;

	// Ligação entre as saídas dos registradores e seus respectivos fios.
	assign WR0 = R0;
	assign WR1 = R1;
	assign WR2 = R2;
	assign WR3 = R3;
	assign WR4 = R4;
	assign WR5 = R5;
	assign WR6 = R6;
	assign WR7 = R7;

	// Ligação entre os controles de acesso a escrita dos registradores A, G e IR aos seus respectivos fios.
	assign WAin = Ain;
	assign WGin = Gin;
	assign WIRin = IRin;

	// Ligação das saídas dos decodificadores de endereço (dec3to8) aos seus respectivos fios.
	assign WXR = Xreg;
	assign WYR = Yreg;

	// Instanciação de decodificadores 3 para 8.
	dec3to8 decX (BusIRout[5:3], EnableDec, Xreg);
	dec3to8 decY (BusIRout[2:0], EnableDec, Yreg);

	// Instanciação dos registradores.
	regn reg_0 (BusWires, BusFSMReg[0], Clock, R0);
	regn reg_1 (BusWires, BusFSMReg[1], Clock, R1);
	regn reg_2 (BusWires, BusFSMReg[2], Clock, R2);
	regn reg_3 (BusWires, BusFSMReg[3], Clock, R3);
	regn reg_4 (BusWires, BusFSMReg[4], Clock, R4);
	regn reg_5 (BusWires, BusFSMReg[5], Clock, R5);
	regn reg_6 (BusWires, BusFSMReg[6], Clock, R6);
	regn reg_7 (BusWires, BusFSMReg[7], Clock, R7);

	// Instanciação dos registradores de entrada (A) e saída (G) da ULA.
	regn reg_A (BusWires, WAin, Clock, Aout);
	regn reg_G (BusWires, WGin, Clock, Gout);

	// Instanciação do registrador de instruções (IR).
	regn reg_IR (BusWires[8:6], IRin, Clock, IRout);

	// Instanciação da ULA.
	ula addSub (BusAout, BusWires, BusIRout[8:6], Uout);

	// Instanciação do multiplexador.
	multiplexador multiplex (WR0, WR1, WR2, WR3, WR4, WR5, WR6, WR7,
							 DIN, BusGout, BusFSMMulti, BusWires);

	// Controle das saídas da FSM
	always @(posedge Clock or negedge Resetn or Tstep_Q or BusIRout or WXR or WYR)
		begin
			/* A FSM se mantém realizando transições entre seus respectivos estados enquanto não há o reset da mesma.
			Quando o reset é colocado em nível lógico baixo, a FSM retorna para o seu estado inicial, e todos os sinais
			referentes ao controle do processador são reiniciados.
			*/
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
				/* Se não há reset, a FSM prossegue com o processamento normal. Para realização do processamento,
				existem quatro tempos, que são ditos pelos ciclos de clock, a saber: T0, T1, T2 e T3.
				*/
				case (Tstep_Q)
					T0:
					/* Em T0, a FSM sinaliza, desabilitando o sinal "done", que o processador está em processamento.
					Ao mesmo tempo, armazena o conteúdo de DIN no registrador IR (acionando a entrada do registrador
					de instruções), habilida os decodificadores 3 para 8 (acionando o sinal EnableDec), e transita para o estado T1.
					*/
					begin
						if (!Run)
							Tstep_Q = T0;
						else
							Done = 1'b0;
							WIRin = 1'b1;
							EnableDec = 1'b1;
							Tstep_Q = T1;
					end

					T1:
					/* Uma vez estando em T1, a FSM desabilita o recebimento de novas instruções pelo IR através do sinal WIRin,
					e prossegue com o processamento.
					*/
						begin
							WIRin = 1'b0;
							case (BusIRout[8:6])
								MV:
								/* Operação move:
								Essa operação move um dado de um determinado registrador Y para um determinado registrador X,
								habilitando a passagem do dado de Y pelo multiplexador, e habilitando o recebimento do dado do
								barramento pelo registrador X. Ao término, o processador sinaliza o término da operação e a
								FSM retorna para o estado inicial.
								*/
									BusFSMMulti = BusIRout[2:0];
									BusFSMReg = WXR;
									Done = 1'b1;
									Tstep_Q = T0;

								MVI:
								/* Operação move immediate:
								Essa operação move uma constante fornecida na entrada DIN para um determinado registrador X,
								habilitando a passagem do dado de DIN pelo multiplexador, e habilitando o recebimento do dado
								do barramento pelo registrador X. Ao término, o processador sinaliza o término da operação e a
								FSM retorna para o estado inicial.
								*/
									BusFSMMulti = DINout_Ctrl;
									BusFSMReg = WXR;
									Done = 1'b1;
									Tstep_Q = T0;

								ADD:
								/* Operação add (parte 1 de 3):
								Essa operação, dividida em três partes, realiza a soma de um dado de um determinado registrador
								X com um dado de um determinado registrador Y, e a armazena no registrador X. Nessa primeira parte,
								a FSM habilita a passagem do dado de X para o registrador A, possibilitando que, posteriormente,
								esse dado seja somado com o dado do registrador Y, em T2. Feito isto, a FSM transita para o estado T2.
								*/
									BusFSMMulti = BusIRout[5:3];
									WAin = 1'b1;
									TStep_Q = T2;

								SUB:
								/* Operação sub (parte 1 de 3):
								Essa operação, dividida em três partes, realiza a subtração de um dado de um determinado registrador
								X com um dado de um determinado registrador Y, e a armazena no	registrador X. Nessa primeira parte,
								a FSM habilita a passagem do dado de X para o registrador A, possibilitando que, posteriormente,
								esse dado seja subtraído com o dado do registrador Y, em T2. Feito isto, a FSM transita para o estado T2.
								*/
									BusFSMMulti = BusIRout[5:3];
									WAin = 1'b1;
									TStep_Q = T2;

							endcase
						end

					T2:
						case (BusIRout[8:6])
							ADD:
							/* Operação add (parte 2 de 3):
							Nesta parte, a FSM habilita a passagem do dado de Y para a ULA, possibilitando que o mesmo seja somado
							com o dado de X já existente no registrador A, e entregue o resultado ao registrador G, que também
							é habilitado nessa etapa. Feito isto, a FSM transita para o estado T3.
							*/
								BusFSMMulti = BusIRout[2:0];
								Gin = 1'b1;
								TStep_Q = T3;

							SUB:
							/* Operação sub (parte 2 de 3):
							Nesta parte, a FSM habilita a passagem do dado de Y para a ULA, possibilitando que o mesmo seja subtraído
							com o dado de X já existente no registrador A, e entregue o resultado ao registrador G, que também
							é habilitado nessa etapa. Feito isto, a FSM transita para o estado T3.
							*/
								BusFSMMulti = BusIRout[2:0];
								Gin = 1'b1;
								TStep_Q = T3;

						endcase

					T3:
						case (BusIRout[8:6])
							ADD:
							/* Operação add (parte 3 de 3):
							Já nessa parte, a FSM habilita a passagem do dado do registrador G pelo multiplexador, possibilitando que
							o mesmo seja armazenado no registrador X, também endereçado nessa parte. Uma vez armazenado, o processador
							sinaliza o término do processamento, habilitando o sinal "done", e transita para o estado inicial (T0),
							para que um novo processamento, que por ventura seja solicitado, seja processado.
							*/
								BusFSMMulti = Gout_Ctrl;
								BusFSMReg = WXR;
								Done = 1'b1;
								Tstep_Q = T0;

							SUB:
							/* Operação sub (parte 3 de 3):
							Já nessa parte, a FSM habilita a passagem do dado do registrador G pelo multiplexador, possibilitando que
							o mesmo seja armazenado no registrador X, também endereçado nessa parte. Uma vez armazenado, o processador
							sinaliza o término do processamento, habilitando o sinal "done", e transita para o estado inicial (T0),
							para que um novo processamento, que por ventura seja solicitado, seja processado.
							*/
								BusFSMMulti = Gout_Ctrl;
								BusFSMReg = WXR;
								Done = 1'b1;
								Tstep_Q = T0;

						endcase
					default:
					/*Caso qualquer erro inesperado ocorra, e faça com que um estado inesperado seja lido,
					a FSM retorna para o seu estado inicial.
					*/
						Tstep_Q = T0;
				endcase
		end
endmodule // proc

module dec3to8(In, Enable, Q);
	/* Decodificador de 3 para 8:
	Este módulo é responsável por receber uma palavra de 3 bits, e decodificá-la em uma palavra de 8 bits,
	que servirá para endereçar os registradores de R0 a R7. Na palavra de 8 bits, o bit setado indica
	qual registrador deve ter sua escrita habilitada e quais não.
	*/
	input [2:0] In;
	input Enable;
	output [0:7] Q;

	reg [0:7] Q;

	always @(In or Enable) begin
		if (Enable == 1)
			case (In)
				3'b000: Q = 8'b00000001;
				3'b001: Q = 8'b00000010;
				3'b010: Q = 8'b00000100;
				3'b011: Q = 8'b00001000;
				3'b100: Q = 8'b00010000;
				3'b101: Q = 8'b00100000;
				3'b110: Q = 8'b01000000;
				3'b111: Q = 8'b10000000;
			endcase
		else
			/* Caso o Enable do decodificador, não esteja em estado ativo , o mesmo
			não habilita a escrita para nenhum registrador.
			*/
			Q = 8'b00000000;
	end
endmodule // dec3to8

module regn(R, Rin, Clock, Q);
	/* Registrador de n bits (onde a quantidade de n é especificada em um parâmetro do código do mesmo):
	Serve para armazenar os dados manipulados durante todo o processamento. Possui um sinal que habilita
	a escrita de um novo dado (Rin).
	*/
	parameter n = 9;
	input [n-1:0] R;
	input Rin, Clock;
	output [n-1:0] Q;
	reg [n-1:0] Q;

	always @(posedge Clock)
		if (Rin)
			Q <= R;
endmodule // regn

module ula(a, b, sel, Q);
	/* Unidade Lógica e Aritmética (ULA):
	Responsável por realizar as somas e as subtrações do processador.
	Recebe duas palavras de n bits (onde a quantidade de n é especificada em um parâmetro do código)
	e, dependendo do sinal do controle (sel), realiza a soma ou a subtração entre as duas palavras.
	*/
	parameter n = 9
	input [n-1:0] a, b;
	input [2:0] sel; // O motivo para que o sel (barramento de controle da ULA) seja de 3 bits é para deixar em aberto
	 				 // para aumentar a quantidade de funções possiveis da ula em uma possivel expansão
	output reg [n-1:0] Q;

	always @(a or b or sel) begin
		case(sel)
			3'b010 : Q = a + b; // Add
			3'b011 : Q = a - b; // Sub
			default : Q = b; // Por default, a ULA deixa passar a palavra B, caso nenhuma instrução válida seja selecionada.
		endcase
	end
endmodule // ula

module multiplexador (R0, R1, R2, R3, R4, R5, R6, R7, DIN, G, CTRL, Q);
	/* Multiplexador de 8 bits:
	   Através do sinal do controle (CTRL), seleciona qual registrador deve ter seu dado fornecido ao barramento.
	*/
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
				default: Q = 9'b0; // Por default, o decodificador fornece zero caso nenhum registrador válido seja selecionado.
			endcase
		end
endmodule // multiplexador
