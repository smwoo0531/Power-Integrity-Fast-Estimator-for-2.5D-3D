%% System PDN modeling tool development log
% *****************11/01/2014 Yang Zhang***********************************
% on-die PDN modeling is developed, Trapezoid scheme used
% *****************06/11/2015 Li Zheng*************************************
% package and board level distributed IR drop analysis implemented
% *****************10/08/2015 Yang Zhang***********************************
% transient analysis with distributed package and board model implemented
% *****************10/12/2016 Yang Zhang***********************************
% validated models against IBMPG benchmark
% imporved on-die modeling and multi-level metal, vias and interleaved tructure is implemented
% *****************10/15/2016 Md Obaidul Hossen****************************
% implemented AC analysis and improved package/board decap modeling based
% on discussions with Yang
% *****************10/15/2016 Yang Zhang***********************************
% improve transient solving by using pre-LU factorization
% *****************10/26/2016 Yang*****************************************
% ***implemented 2.5-D integration such as EMIB, interposer and HIST config

%% clear caches

%clc
clear
for ppp = 3:40
for iii = 1
close all

period = 1e-9;
system.bridge_ground = 0;
system.bridge_power = 0;
system.bridge.FLAG = iii;
edge = 1e-3;
system.chip.N = 2;
%% for Chip # 1 parameters %%
chip(1).N = 1;
chip(1).Xsize = 1e-2; %chip x dimension; y dimension below
chip(1).Ysize = 1e-2;

chip(1).Metal.N = [4];
chip(1).Metal.p = [18e-9]; % wire resistivity
chip(1).Metal.ar = [1.8 1.8 1.8 0.4];

chip(1).Metal.pitch = [160e-9 160e-9 360e-9 30e-6]*2;
chip(1).Metal.thick = [144e-9 144e-9 324e-9 7e-6];
                   
chip(1).Via.R = [0.4253 0.4253 0.1890 0]*450;
chip(1).Via.N = [4e9 4e9 8e8 1e5]/45;

chip(1).cap_per = [0.05];
chip(1).cap_th = [0.9e-9]; %capacitance effective thicknee (used for capacitance value calculation)

chip(1).power = ppp*5; %total power dissipation of each die
bank_power = 0*100e-3;
% bank_map = [0.5e-3 0.2e-3 2.0e-3 0.5e-3 0 0.05;
%             0.5e-3 0.8e-3 2.0e-3 0.5e-3 0 0.05;
%             0.5e-3 1.4e-3 2.0e-3 0.5e-3 0 0.05;
%             0.5e-3 2e-3 2.0e-3 0.5e-3 0 0.05;
%             0.5e-3 2.6e-3 2.0e-3 0.5e-3 0 0.05;
%             0.5e-3 3.2e-3 2.0e-3 0.5e-3 0 0.05;
%             0.5e-3 3.8e-3 2.0e-3 0.5e-3 0 0.05;
%             0.5e-3 4.4e-3 2.0e-3 0.5e-3 0 0.05;
%             0.5e-3 5e-3 2.0e-3 0.5e-3 0 0.05;
%             0.5e-3 5.6e-3 2.0e-3 0.5e-3 0 0.05;
%             0.5e-3 6.2e-3 2.0e-3 0.5e-3 0 0.05;
%             0.5e-3 6.8e-3 2.0e-3 0.5e-3 0 0.05;
%             0.5e-3 7.4e-3 2.0e-3 0.5e-3 0 0.05;
%             0.5e-3 8e-3 2.0e-3 0.5e-3 0 0.05;
%             0.5e-3 8.6e-3 2.0e-3 0.5e-3 0 0.05;
%             0.5e-3 9.2e-3 2.0e-3 0.5e-3 0 0.05;
%             ];
% bank_map1 = bank_map;
% bank_map1(:,1) = bank_map1(:,1)+2.1e-3;
% bank_map2 = bank_map1;
% bank_map2(:,1) = 5.4e-3;
% bank_map3 = bank_map2;
% bank_map3(:,1) = bank_map3(:,1)+2.1e-3;
% 
% bank_map(1,5) = bank_power;
% bank_map(9,5) = bank_power;
% bank_map2(1,5) = bank_power;
% bank_map2(9,5) = bank_power;
% 
% die1_map = [   bank_map;
%                 bank_map1;
%                 4.7e-3 0.2e-3 0.6e-3 9.6e-3 100e-3 0.05;
%                 bank_map2;
%                 bank_map3;];
%             
% bank_map(1,5) = 0;
% bank_map(9,5) = 0;
% bank_map2(1,5) = 0;
% bank_map2(9,5) = 0;
% 
% bank_map(5,5) = bank_power;
% bank_map(13,5) = bank_power;
% bank_map2(5,5) = bank_power;
% bank_map2(13,5) = bank_power;
% 
% die2_map = [   bank_map;
%                 bank_map1;
%                 4.7e-3 0.2e-3 0.6e-3 9.6e-3 0*100e-3 0.05;
%                 bank_map2;
%                 bank_map3;];
%             
% bank_map(5,5) = 0;
% bank_map(13,5) = 0;
% bank_map2(5,5) = 0;
% bank_map2(13,5) = 0;
% 
% bank_map1(1,5) = bank_power;
% bank_map1(9,5) = bank_power;
% bank_map3(1,5) = bank_power;
% bank_map3(9,5) = bank_power;
% 
% die3_map = [   bank_map;
%                 bank_map1;
%                 4.7e-3 0.2e-3 0.6e-3 9.6e-3 0*100e-3 0.05;
%                 bank_map2;
%                 bank_map3;];
%             
% bank_map1(1,5) = 0;
% bank_map1(9,5) = 0;
% bank_map3(1,5) = 0;
% bank_map3(9,5) = 0;
% 
% bank_map1(5,5) = bank_power;
% bank_map1(13,5) = bank_power;
% bank_map3(5,5) = bank_power;
% bank_map3(13,5) = bank_power;
% 
% die4_map = [   bank_map;
%                 bank_map1;
%                 4.7e-3 0.2e-3 0.6e-3 9.6e-3 0*100e-3 0.05;
%                 bank_map2;
%                 bank_map3;];

chip(1).map = [
                0 0 10e-3 10e-3 chip(1).power 0.05;
              ];
chip(1).tsv_map = [4.7e-3 0.2e-3 0.6e-3 9.6e-3 0*100e-3 0.05];
% chip(1).power = [80];
% chip(1).map = [];
%chip(1).map(:,6) = chip(1).map(:,6);
%chip(1).map(:,5) = chip(1).map(:,5)*0.5;
chip(1).Tp = period; %period
chip(1).Tr = 0.4e-9; %rise time
chip(1).Tf = 0.4e-9; %fall time
chip(1).Tc = 0.2e-9; %fall time

chip(1).blk_name = cell(65, 1);
chip(1).blk_name(:) = cellstr('');
chip(1).blk_name(3) = cellstr('');
chip(1).blk_name(5) = cellstr('');
chip(1).blk_name(8) = cellstr('');
chip(1).name = cellstr('stacked memory');  

%blk_num is for splitting the power maps of each die
% format: xl corner, yb corner, x size, y size, power, decap %
chip(1).blk_num = [1];

%% for TSV domain %%
chip(1).TSV.d = 7e-6; %TSV diameter
chip(1).TSV.contact = 0.45*1e-6^2; %resistance per unit area
chip(1).TSV.liner = 0.2e-6;
chip(1).TSV.mu = 1.257e-6;
chip(1).TSV.rou = 80e-9; % resistivity of copper
chip(1).TSV.thick = 50e-6;

chip(1).ubump.rou = 400e-9;
chip(1).ubump.d = 50e-6;
chip(1).ubump.h = 40e-6;
chip(1).ubump.px = 200e-6;
chip(1).ubump.py = 200e-6;
chip(1).ubump.mu = 1.257e-6;
chip(1).ubump.scale = 2; %accounting for contact resistance

chip(1).c4.rou = 400e-9;
chip(1).c4.d = 25e-6;
chip(1).c4.h = 40e-6;
chip(1).c4.px = 100e-6;
chip(1).c4.py = 100e-6;
chip(1).c4.mu = 1.257e-6;
chip(1).c4.scale = 2; %accounting for contact resistance
chip(1).c4.Nbundle = 5;

chip(1).meshlvl = 0;
%% for Chip # 2 parameters %%
chip(2).N = 1; %die number
chip(2).Xsize = 1e-2; %chip x dimension; y dimension below
chip(2).Ysize = 1e-2;

chip(2).Metal.N = [6];
chip(2).Metal.p = [18e-9]; % wire resistivity
chip(2).Metal.ar = [1.8 1.8 1.8 1.8 1.8 0.4 0.4 0.4 0.4 0.4];

chip(2).Metal.pitch = [160e-9 160e-9 360e-9 560e-9 810e-9 30.5e-6 30.5e-6 30.5e-6 30.5e-6 30.5e-6]*2;
chip(2).Metal.thick = [144e-9 144e-9 324e-9 504e-9 720e-9 7e-6 7e-6 7e-6 7e-6 7e-6];

chip(2).Via.R = [0.4253 0.4253 0.1890 0.1215 0.0851 0.000432 0 0 0 0 0]*45;
chip(2).Via.N = [4e9 4e9 8e8 3e8 1.5e8 1e5 1e5 1e5 1e5 1e5 1e5]/45;

chip(2).cap_per = [0.05];% 0.1 0.1]; %decap number
chip(2).cap_th = [0.9e-9]; %capacitance effective thicknee (used for capacitance value calculation)

chip(2).power = [44.8]; %total power dissipation of each die
chip(2).map = [0.1e-3 0.1e-3 1.0e-3 1.0e-3 44.8*0.01 0.05; % PLL
                0.1e-3 1.2e-3 1.0e-3 3.2e-3 44.8*0.015 0.05; % PPA SMALL
                0.1e-3 4.5e-3 1.0e-3 1.0e-3 44.8*0.01 0.05; % PLL
                0.1e-3 5.6e-3 1.0e-3 3.2e-3 44.8*0.015 0.05; % PPA SMALL
                0.1e-3 8.9e-3 1.0e-3 1.0e-3 44.8*0.01 0.05; % PLL
                2.0e-3 0.1e-3 6.0e-3 1.0e-3 44.8*0.11 0.05; % TX die
                8.9e-3 0.1e-3 1.0e-3 1.0e-3 44.8*0.011 0.05; % PPA SMALL
                8.9e-3 2.0e-3 1.0e-3 6.0e-3 44.8*0.10 0.05; % TX die
                8.9e-3 8.9e-3 1.0e-3 1.0e-3 44.8*0.011 0.05; % PPA SMALL
                1.2e-3 8.9e-3 3.7e-3 1.0e-3 44.8*0.040 0.05; % PPA big
                5.1e-3 8.9e-3 3.7e-3 1.0e-3 44.8*0.035 0.05; % PPA big
                1.7e-3 1.3e-3 0.3e-3 7.4e-3 44.8*0.05 0.05; % DSP
                2.1e-3 1.3e-3 1.0e-3 7.4e-3 44.8*0.04 0.05; % m4k ram
                3.2e-3 3.5e-3 1.1e-3 3.0e-3 44.8*0.04 0.05; % m ram
                4.4e-3 1.3e-3 1.1e-3 7.4e-3 44.8*0.05 0.05; % m4k ram
                5.6e-3 3.5e-3 1.1e-3 3.0e-3 44.8*0.04 0.05; % m ram
                6.8e-3 1.3e-3 1.0e-3 7.4e-3 44.8*0.04 0.05; % m4k ram
                7.9e-3 1.3e-3 0.3e-3 7.4e-3 44.8*0.05 0.05; % DSP
                1.2e-3 0.1e-3 0.7e-3 1.0e-3 44.8*0.006 0.05;
                8.1e-3 0.1e-3 0.7e-3 1.0e-3 44.8*0.004 0.05;
                8.9e-3 1.2e-3 1.0e-3 0.7e-3 44.8*0.008 0.05;
                8.9e-3 8.1e-3 1.0e-3 0.7e-3 44.8*0.002 0.05];
%chip(2).map(:,6) = chip(2).map(:,6);       
chip(2).blk_name = cell(23,1);
chip(2).blk_name(:) = cellstr('');
chip(2).blk_name(6) = cellstr('Tx');
chip(2).blk_name(8) = cellstr('Tx');
chip(2).name = cellstr('FPGA');    
chip(2).blk_num = [22];  
chip(2).Tp = period; %period
chip(2).Tr = 0.4e-9; %rise time
chip(2).Tf = 0.4e-9; %fall time  
chip(2).Tc = 0.2e-9; %fall time

%blk_num is for splitting the power maps of each die
% format: xl corner, yb corner, x size, y size, power, decap %

chip(2).TSV.d = 7e-6; %TSV diameter
chip(2).TSV.contact = 0.45*1e-6^2; %resistance per unit area
chip(2).TSV.liner = 0.2e-6;
chip(2).TSV.mu = 1.257e-6;
chip(2).TSV.rou = 80e-9; % resistivity of copper
chip(2).TSV.thick = 125e-6;

chip(2).ubump.rou = 400e-9;
chip(2).ubump.d = 50e-6;
chip(2).ubump.h = 40e-6;
chip(2).ubump.px = 200e-6;
chip(2).ubump.py = 200e-6;
chip(2).ubump.mu = 1.257e-6;
chip(2).ubump.scale = 2; %accounting for contact resistance

chip(2).c4.rou = 400e-9;
chip(2).c4.d = 25e-6;
chip(2).c4.h = 40e-6;
chip(2).c4.px = 100e-6;
chip(2).c4.py = 100e-6;
chip(2).c4.mu = 1.257e-6;
chip(2).c4.scale = 2; %accounting for contact resistance
chip(2).c4.Nbundle = 5;

chip(2).meshlvl = 0;
%% Package parameters
system.pkg.Xsize = 2.45e-2; % Intel LAG 1366 package
system.pkg.Ysize = 1.8e-2;

system.pkg.wire_p = 180e-9;
system.pkg.N = 10;
system.pkg.wire_thick = 0.02e-3;

% package decap format: xl, yb, xsize, ysize, c, esl, esr
system.pkg.decap = [52e-6 5.61e-13*2.5/1.5 541.5e-9/8];
system.pkg.Rs = 1.2; %unit: ohm/m
system.pkg.Ls = 2.4e-8; %unit: H/m
%system.pkg.decap(:,5) = system.pkg.decap(:,5)*2;
%system.pkg.Cdst = 2e-9*1e4; % F per m^2  
system.pkg.ViaR = 1e-4/2;
system.pkg.ViaN = 1e3;
system.pkg.mu = 1.257e-6;
%% board parameters
%%%%%Board parasitics%%%%%%%
system.board.Rs = 166e-6;
system.board.Ls = 21e-12;

%board decap format: c, esl, esr
system.board.decap = [
                        240e-6 19.536e-6 166e-6
                     ];

                  
                  
system.BGA.rou = 123e-9;
system.BGA.d = 250e-6;
system.BGA.h = 1000e-6;
system.BGA.px = 1e-3;
system.BGA.py = 1e-3;
system.BGA.mu = 1.257e-6;
system.BGA.scale = 5;

%% package and chip positions (lower-left corner);
chip(1).xl = 12.5e-3;
chip(1).yb = 4e-3;

chip(2).xl = 2e-3;
chip(2).yb = 4e-3;

if system.bridge.FLAG == 0
    system.connect = [];
elseif system.bridge.FLAG == 1
    system.connect = [chip(2).xl+chip(2).Xsize-edge chip(2).yb+0.2e-3 edge*5+0.5e-3 9.6e-3, 0, 0];
elseif system.bridge.FLAG == 2
    system.connect = [chip(2).xl+chip(2).Xsize-edge chip(2).yb+1.5e-3 edge*2+0.5e-3 3e-3, 0, 0
                      chip(2).xl+chip(2).Xsize-edge chip(2).yb+5.5e-3 edge*2+0.5e-3 3e-3, 0, 0];
elseif system.bridge.FLAG == 3                  
system.connect = [chip(2).xl+chip(2).Xsize-edge chip(2).yb+1e-3 edge*2+0.5e-3 2e-3, 0, 0
                  chip(2).xl+chip(2).Xsize-edge chip(2).yb+4e-3 edge*2+0.5e-3 2e-3, 0, 0
                  chip(2).xl+chip(2).Xsize-edge chip(2).yb+7e-3 edge*2+0.5e-3 2e-3, 0, 0];
elseif system.bridge.FLAG == 4
system.connect = [chip(2).xl+chip(2).Xsize-edge chip(2).yb+0.8e-3 edge*2+0.5e-3 1.5e-3, 0, 0
                  chip(2).xl+chip(2).Xsize-edge chip(2).yb+3.1e-3 edge*2+0.5e-3 1.5e-3, 0, 0
                  chip(2).xl+chip(2).Xsize-edge chip(2).yb+5.4e-3 edge*2+0.5e-3 1.5e-3, 0, 0
                  chip(2).xl+chip(2).Xsize-edge chip(2).yb+7.7e-3 edge*2+0.5e-3 1.5e-3, 0, 0];
elseif system.bridge.FLAG == 5
system.connect = [chip(2).xl+chip(2).Xsize-edge chip(2).yb+0.6e-3 edge*2+0.5e-3 1.2e-3, 0, 0
                  chip(2).xl+chip(2).Xsize-edge chip(2).yb+2.5e-3 edge*2+0.5e-3 1.2e-3, 0, 0
                  chip(2).xl+chip(2).Xsize-edge chip(2).yb+4.4e-3 edge*2+0.5e-3 1.2e-3, 0, 0
                  chip(2).xl+chip(2).Xsize-edge chip(2).yb+6.3e-3 edge*2+0.5e-3 1.2e-3, 0, 0
                  chip(2).xl+chip(2).Xsize-edge chip(2).yb+8.2e-3 edge*2+0.5e-3 1.2e-3, 0, 0];
else
system.connect = [chip(2).xl+chip(2).Xsize-edge chip(2).yb+0.5e-3 edge*2+0.5e-3 1e-3, 0, 0
                  chip(2).xl+chip(2).Xsize-edge chip(2).yb+2.1e-3 edge*2+0.5e-3 1e-3, 0, 0
                  chip(2).xl+chip(2).Xsize-edge chip(2).yb+3.7e-3 edge*2+0.5e-3 1e-3, 0, 0
                  chip(2).xl+chip(2).Xsize-edge chip(2).yb+5.3e-3 edge*2+0.5e-3 1e-3, 0, 0
                  chip(2).xl+chip(2).Xsize-edge chip(2).yb+6.9e-3 edge*2+0.5e-3 1e-3, 0, 0
                  chip(2).xl+chip(2).Xsize-edge chip(2).yb+8.5e-3 edge*2+0.5e-3 1e-3, 0, 0];    
end
%system.connect = [];
%%%%%%%%bridge decap%%%%%%%%%%%
system.bridge_decap = 5e-3; %5 nF/mm2 bridge decap


system.inter = 0;
system.emib = 1;
system.emib_via = 0;
system.stacked_die = 1;
system.TSV.Nbundle = 10;
system.TSV.d = 10e-6; % TSV diameter
system.TSV.px = 400e-6; %TSV X pitch (p2p/g2g)
system.TSV.py = 400e-6; %TSV Y pitch (p2p/g2g)
system.TSV.contact = 0; %resistance per unit area
system.TSV.liner = 0.5e-6;
system.TSV.mu = 1.257e-6;
system.TSV.rou = 30e-9; % resistivity of copper
system.TSV.thick = 100e-6;

%% for system level parameters
system.tran = 0; % transient analysis or not;
system.write = 1; %whether to write the data or not
system.gif = 0; % whether to draw the gifs along simulations
system.draw = 1; %whether to draw the noise map for transient analysis
system.tranplot = 1; %whether to draw the noise map for transient analysis
system.drawP = 0; %display the current requirement map
system.drawC = 0; %display the decap distribution
system.drawM = 0; %display the mesh or not
system.clamp = 0;
system.range = [30 100];
system.skip = 0; % skip running but read and plot data directly
system.TR_FLAG = 1; %whether to use trapezoid scheme

system.T = 100e-9; %transient simulation time 
system.dt = 0.025e-9; %simulation step, TR scheme is stable for 0.1e-9, which is pretty optimized

system.Vdd.val = 0.9; %VDD value for of VRM

%% main running script
power_noise_sim(system, chip);
end
end