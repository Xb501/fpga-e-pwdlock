//Copyright (C)2014-2025 Gowin Semiconductor Corporation.
//All rights reserved.
//File Title: Template file for instantiation
//Tool Version: V1.9.11.03 Education
//Part Number: GW2A-LV18PG256C8/I7
//Device: GW2A-18
//Device Version: C
//Created Time: Sun May 31 23:09:34 2026

//Change the instance name and port connections to the signal names
//--------Copy here to design--------

	fifo_sc your_instance_name(
		.Data(Data), //input [7:0] Data
		.Clk(Clk), //input Clk
		.WrEn(WrEn), //input WrEn
		.RdEn(RdEn), //input RdEn
		.Reset(Reset), //input Reset
		.Almost_Empty(Almost_Empty), //output Almost_Empty
		.Q(Q), //output [7:0] Q
		.Empty(Empty), //output Empty
		.Full(Full) //output Full
	);

//--------Copy end-------------------
