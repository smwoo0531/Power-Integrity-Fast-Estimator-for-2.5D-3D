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

clc
clear
for iii = 0
    close all

    %% Input excel details
    ip_file_name = './inputs/tb_inputs_new.xlsx';
    system_sheet = 'system';
    chip_sheet = 'chip';
    block_level_specs_sheet = 'block_layout_specs';


    period = readvars(ip_file_name, 'UseExcel', true, 'Sheet', system_sheet, 'Range', 'E3:E3');
    edge = readvars(ip_file_name, 'UseExcel', true, 'Sheet', system_sheet, 'Range', 'E4:E4');
    system.bridge_ground = readvars(ip_file_name, 'UseExcel', true, 'Sheet', system_sheet, 'Range', 'E5:E5');
    system.bridge_power = readvars(ip_file_name, 'UseExcel', true, 'Sheet', system_sheet, 'Range', 'E6:E6');
    system.bridge.FLAG = iii;
    system.chip.N = readvars(ip_file_name, 'UseExcel', true, 'Sheet', system_sheet, 'Range', 'E7:E7');
    %% for Chip # 1 parameters %%
    chip(1).N = 1;
    chip(1).Xsize = readvars(ip_file_name, 'UseExcel', true, 'Sheet', chip_sheet, 'Range', 'E7:E7'); %chip x dimension; y dimension below
    chip(1).Ysize = readvars(ip_file_name, 'UseExcel', true, 'Sheet', chip_sheet, 'Range', 'E8:E8');

    chip(1).Metal.N = readmatrix(ip_file_name, 'UseExcel', true, 'Sheet', chip_sheet, 'Range', 'E10:F10');
    chip(1).Metal.p = readmatrix(ip_file_name, 'UseExcel', true, 'Sheet', chip_sheet, 'Range', 'E11:F11'); % wire resistivity
    chip(1).Metal.ar = readmatrix(ip_file_name, 'UseExcel', true, 'Sheet', chip_sheet, 'Range', 'E12:L12');

    chip(1).Metal.pitch = readmatrix(ip_file_name, 'UseExcel', true, 'Sheet', chip_sheet, 'Range', 'E13:L13')*2;
    chip(1).Metal.thick = readmatrix(ip_file_name, 'UseExcel', true, 'Sheet', chip_sheet, 'Range', 'E14:L14');

    chip(1).Via.R = readmatrix(ip_file_name, 'UseExcel', true, 'Sheet', chip_sheet, 'Range', 'E16:L16')*450;
    chip(1).Via.N = readmatrix(ip_file_name, 'UseExcel', true, 'Sheet', chip_sheet, 'Range', 'E17:L17')/45;

    chip(1).cap_per = readmatrix(ip_file_name, 'UseExcel', true, 'Sheet', chip_sheet, 'Range', 'E19:F19');
    chip(1).cap_th = readmatrix(ip_file_name, 'UseExcel', true, 'Sheet', chip_sheet, 'Range', 'E20:F20'); %capacitance effective thicknee (used for capacitance value calculation)

    chip(1).power = readmatrix(ip_file_name, 'UseExcel', true, 'Sheet', chip_sheet, 'Range', 'E22:F22'); %total power dissipation of each die
    bank_power = readvars(ip_file_name, 'UseExcel', true, 'Sheet', chip_sheet, 'Range', 'E55:F55');

    bank_map = [];

    chip(1).map = [ ];
    chip(1).tsv_map = readmatrix(ip_file_name, 'UseExcel', true, 'Sheet', chip_sheet, 'Range', 'E26:J26');
    % chip(1).power = [80];
    % chip(1).map = [];
    %chip(1).map(:,6) = chip(1).map(:,6);
    %chip(1).map(:,5) = chip(1).map(:,5)*0.5;
    chip(1).Tp = period; %period
    chip(1).Tr = readvars(ip_file_name, 'UseExcel', true, 'Sheet', chip_sheet, 'Range', 'E52:F52'); %rise time
    chip(1).Tf = readvars(ip_file_name, 'UseExcel', true, 'Sheet', chip_sheet, 'Range', 'E53:F53'); %fall time
    chip(1).Tc = readvars(ip_file_name, 'UseExcel', true, 'Sheet', chip_sheet, 'Range', 'E54:F54'); %fall time

    chip(1).blk_name = cell(65, 1);
    chip(1).blk_name(:) = cellstr('');
    chip(1).blk_name(3) = cellstr('');
    chip(1).blk_name(5) = cellstr('');
    chip(1).blk_name(8) = cellstr('');
    chip(1).name = cellstr('stacked memory');  

    %blk_num is for splitting the power maps of each die
    % format: xl corner, yb corner, x size, y size, power, decap %
    chip(1).blk_num = readmatrix(ip_file_name, 'UseExcel', true, 'Sheet', chip_sheet, 'Range', 'E51:F51');

    %% for TSV domain %%
    chip(1).TSV.d = readvars(ip_file_name, 'UseExcel', true, 'Sheet', chip_sheet, 'Range', 'E27:E27'); %TSV diameter
    chip(1).TSV.contact = readvars(ip_file_name, 'UseExcel', true, 'Sheet', chip_sheet, 'Range', 'E28:E28'); %resistance per unit area
    chip(1).TSV.liner = readvars(ip_file_name, 'UseExcel', true, 'Sheet', chip_sheet, 'Range', 'E29:E29');
    chip(1).TSV.mu = readvars(ip_file_name, 'UseExcel', true, 'Sheet', chip_sheet, 'Range', 'E30:E30');
    chip(1).TSV.rou = readvars(ip_file_name, 'UseExcel', true, 'Sheet', chip_sheet, 'Range', 'E31:E31'); % resistivity of copper
    chip(1).TSV.thick = readvars(ip_file_name, 'UseExcel', true, 'Sheet', chip_sheet, 'Range', 'E32:E32');

    chip(1).ubump.rou = readvars(ip_file_name, 'UseExcel', true, 'Sheet', chip_sheet, 'Range', 'E34:E34');
    chip(1).ubump.d = readvars(ip_file_name, 'UseExcel', true, 'Sheet', chip_sheet, 'Range', 'E35:E35');
    chip(1).ubump.h = readvars(ip_file_name, 'UseExcel', true, 'Sheet', chip_sheet, 'Range', 'E36:E36');
    chip(1).ubump.px = readvars(ip_file_name, 'UseExcel', true, 'Sheet', chip_sheet, 'Range', 'E37:E37');
    chip(1).ubump.py = readvars(ip_file_name, 'UseExcel', true, 'Sheet', chip_sheet, 'Range', 'E38:E38');
    chip(1).ubump.mu = readvars(ip_file_name, 'UseExcel', true, 'Sheet', chip_sheet, 'Range', 'E39:E39');
    chip(1).ubump.scale = readvars(ip_file_name, 'UseExcel', true, 'Sheet', chip_sheet, 'Range', 'E40:E40'); %accounting for contact resistance

    chip(1).c4.rou = readvars(ip_file_name, 'UseExcel', true, 'Sheet', chip_sheet, 'Range', 'E42:E42');
    chip(1).c4.d = readvars(ip_file_name, 'UseExcel', true, 'Sheet', chip_sheet, 'Range', 'E43:E43');
    chip(1).c4.h = readvars(ip_file_name, 'UseExcel', true, 'Sheet', chip_sheet, 'Range', 'E44:E44');
    chip(1).c4.px = readvars(ip_file_name, 'UseExcel', true, 'Sheet', chip_sheet, 'Range', 'E45:E45');
    chip(1).c4.py = readvars(ip_file_name, 'UseExcel', true, 'Sheet', chip_sheet, 'Range', 'E46:E46');
    chip(1).c4.mu = readvars(ip_file_name, 'UseExcel', true, 'Sheet', chip_sheet, 'Range', 'E47:E47');
    chip(1).c4.scale = readvars(ip_file_name, 'UseExcel', true, 'Sheet', chip_sheet, 'Range', 'E48:E48'); %accounting for contact resistance
    chip(1).c4.Nbundle = readvars(ip_file_name, 'UseExcel', true, 'Sheet', chip_sheet, 'Range', 'E49:E49');

    chip(1).meshlvl = readvars(ip_file_name, 'UseExcel', true, 'Sheet', chip_sheet, 'Range', 'E50:E50');

    %% Package parameters
    system.pkg.Xsize = readvars(ip_file_name, 'UseExcel', true, 'Sheet', system_sheet, 'Range', 'E8:E8'); % Intel LAG 1366 package
    system.pkg.Ysize = readvars(ip_file_name, 'UseExcel', true, 'Sheet', system_sheet, 'Range', 'E9:E9');

    system.pkg.wire_p = readvars(ip_file_name, 'UseExcel', true, 'Sheet', system_sheet, 'Range', 'E10:E10');
    system.pkg.N = readvars(ip_file_name, 'UseExcel', true, 'Sheet', system_sheet, 'Range', 'E11:E11');
    system.pkg.wire_thick = readvars(ip_file_name, 'UseExcel', true, 'Sheet', system_sheet, 'Range', 'E12:E12');

    % package decap format: xl, yb, xsize, ysize, c, esl, esr
    system.pkg.decap = readmatrix(ip_file_name, 'UseExcel', true, 'Sheet', system_sheet, 'Range', 'E13:G13');
    system.pkg.Rs = readvars(ip_file_name, 'UseExcel', true, 'Sheet', system_sheet, 'Range', 'E14:E14'); %unit: ohm/m
    system.pkg.Ls = readvars(ip_file_name, 'UseExcel', true, 'Sheet', system_sheet, 'Range', 'E15:E15'); %unit: H/m
    %system.pkg.decap(:,5) = system.pkg.decap(:,5)*2;
    %system.pkg.Cdst = 2e-9*1e4; % F per m^2  
    system.pkg.ViaR = readvars(ip_file_name, 'UseExcel', true, 'Sheet', system_sheet, 'Range', 'E16:E16');
    system.pkg.ViaN = readvars(ip_file_name, 'UseExcel', true, 'Sheet', system_sheet, 'Range', 'E17:E17');
    system.pkg.mu = readvars(ip_file_name, 'UseExcel', true, 'Sheet', system_sheet, 'Range', 'E18:E18');
    %% board parameters
    %%%%%Board parasitics%%%%%%%
    system.board.Rs = readvars(ip_file_name, 'UseExcel', true, 'Sheet', system_sheet, 'Range', 'E19:E19');
    system.board.Ls = readvars(ip_file_name, 'UseExcel', true, 'Sheet', system_sheet, 'Range', 'E20:E20');

    %board decap format: c, esl, esr
    system.board.decap = readmatrix(ip_file_name, 'UseExcel', true, 'Sheet', system_sheet, 'Range', 'E21:G21');



    system.BGA.rou = readvars(ip_file_name, 'UseExcel', true, 'Sheet', system_sheet, 'Range', 'E22:E22');
    system.BGA.d = readvars(ip_file_name, 'UseExcel', true, 'Sheet', system_sheet, 'Range', 'E23:E23');
    system.BGA.h = readvars(ip_file_name, 'UseExcel', true, 'Sheet', system_sheet, 'Range', 'E24:E24');
    system.BGA.px = readvars(ip_file_name, 'UseExcel', true, 'Sheet', system_sheet, 'Range', 'E25:E25');
    system.BGA.py = readvars(ip_file_name, 'UseExcel', true, 'Sheet', system_sheet, 'Range', 'E26:E26');
    system.BGA.mu = readvars(ip_file_name, 'UseExcel', true, 'Sheet', system_sheet, 'Range', 'E27:E27');
    system.BGA.scale = readvars(ip_file_name, 'UseExcel', true, 'Sheet', system_sheet, 'Range', 'E28:E28');

    %% package and chip positions (lower-left corner);
    % chip(1).xl = 12.5e-3;
    % chip(1).yb = 4e-3;

    chip(1).xl = (system.pkg.Xsize - chip(1).Xsize)/2 ;
    chip(1).yb = (system.pkg.Ysize - chip(1).Ysize)/2 ;

    % chip(2).xl = 2e-3;
    % chip(2).yb = 4e-3;

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
    system.bridge_decap = readvars(ip_file_name, 'UseExcel', true, 'Sheet', system_sheet, 'Range', 'E29:E29'); %5 nF/mm2 bridge decap


    system.inter = readvars(ip_file_name, 'UseExcel', true, 'Sheet', system_sheet, 'Range', 'E30:E30');
    system.emib = readvars(ip_file_name, 'UseExcel', true, 'Sheet', system_sheet, 'Range', 'E31:E31');
    system.emib_via = readvars(ip_file_name, 'UseExcel', true, 'Sheet', system_sheet, 'Range', 'E32:E32');
    system.stacked_die = readvars(ip_file_name, 'UseExcel', true, 'Sheet', system_sheet, 'Range', 'E33:E33');
    system.TSV.Nbundle = readvars(ip_file_name, 'UseExcel', true, 'Sheet', system_sheet, 'Range', 'E34:E34');
    system.TSV.d = readvars(ip_file_name, 'UseExcel', true, 'Sheet', system_sheet, 'Range', 'E35:E35'); % TSV diameter
    system.TSV.px = readvars(ip_file_name, 'UseExcel', true, 'Sheet', system_sheet, 'Range', 'E36:E36'); %TSV X pitch (p2p/g2g)
    system.TSV.py = readvars(ip_file_name, 'UseExcel', true, 'Sheet', system_sheet, 'Range', 'E37:E37'); %TSV Y pitch (p2p/g2g)
    system.TSV.contact = readvars(ip_file_name, 'UseExcel', true, 'Sheet', system_sheet, 'Range', 'E38:E38'); %resistance per unit area
    system.TSV.liner = readvars(ip_file_name, 'UseExcel', true, 'Sheet', system_sheet, 'Range', 'E39:E39');
    system.TSV.mu = readvars(ip_file_name, 'UseExcel', true, 'Sheet', system_sheet, 'Range', 'E40:E40');
    system.TSV.rou = readvars(ip_file_name, 'UseExcel', true, 'Sheet', system_sheet, 'Range', 'E41:E41'); % resistivity of copper
    system.TSV.thick = readvars(ip_file_name, 'UseExcel', true, 'Sheet', system_sheet, 'Range', 'E42:E42');

    %% for system level parameters
    system.tran = readvars(ip_file_name, 'UseExcel', true, 'Sheet', system_sheet, 'Range', 'E43:E43'); % transient analysis or not;
    system.write = readvars(ip_file_name, 'UseExcel', true, 'Sheet', system_sheet, 'Range', 'E44:E44'); %whether to write the data or not
    system.gif = readvars(ip_file_name, 'UseExcel', true, 'Sheet', system_sheet, 'Range', 'E45:E45'); % whether to draw the gifs along simulations
    system.draw = readvars(ip_file_name, 'UseExcel', true, 'Sheet', system_sheet, 'Range', 'E46:E46'); %whether to draw the noise map for transient analysis
    system.tranplot = readvars(ip_file_name, 'UseExcel', true, 'Sheet', system_sheet, 'Range', 'E47:E47'); %whether to draw the noise map for transient analysis
    system.drawP = readvars(ip_file_name, 'UseExcel', true, 'Sheet', system_sheet, 'Range', 'E48:E48'); %display the current requirement map
    system.drawC = readvars(ip_file_name, 'UseExcel', true, 'Sheet', system_sheet, 'Range', 'E49:E49'); %display the decap distribution
    system.drawM = readvars(ip_file_name, 'UseExcel', true, 'Sheet', system_sheet, 'Range', 'E50:E50'); %display the mesh or not
    system.clamp = readvars(ip_file_name, 'UseExcel', true, 'Sheet', system_sheet, 'Range', 'E51:E51');
    system.range = readmatrix(ip_file_name, 'UseExcel', true, 'Sheet', system_sheet, 'Range', 'E52:F52');
    system.skip = readvars(ip_file_name, 'UseExcel', true, 'Sheet', system_sheet, 'Range', 'E53:E53'); % skip running but read and plot data directly
    system.TR_FLAG = readvars(ip_file_name, 'UseExcel', true, 'Sheet', system_sheet, 'Range', 'E54:E54'); %whether to use trapezoid scheme

    system.T = readvars(ip_file_name, 'UseExcel', true, 'Sheet', system_sheet, 'Range', 'E55:E55'); %transient simulation time 
    system.dt = readvars(ip_file_name, 'UseExcel', true, 'Sheet', system_sheet, 'Range', 'E56:E56'); %simulation step, TR scheme is stable for 0.1e-9, which is pretty optimized

    system.Vdd.val = readvars(ip_file_name, 'UseExcel', true, 'Sheet', system_sheet, 'Range', 'E57:E57'); %VDD value for of VRM


    %% block layout specs

    cell_count = 4;
    sim_case = [1];

%     ubump_pitch = [40, 80, 120, 160, 200]*1e-6; % Design Parameter 1
%     ubump_dia = [20]*1e-6;
    ubump_pitch = [100]*1e-6; % Design Parameter 1
    ubump_dia = [50]*1e-6;

    c4_pitch = [100]*1e-6;
    c4_dia = [50]*1e-6;
    substrate_thick = readvars(ip_file_name, 'Sheet', block_level_specs_sheet, 'Range', 'C5:C5'); %units: m

%         tsv_pitch = [6, 10, 20, 30, 40]*1e-6;
%     tsv_diameter = [3, 5, 10, 15, 20]*1e-6;  % Design Parameter 2
    tsv_pitch = [6]*1e-6;
    tsv_diameter = [3]*1e-6;  % Design Parameter 2
%     tsv_map_clustered = [4.01E-03 0.1E-03 0.69E-03 8.60E-03 1.00E-01 5.00E-02]; %clustered TSV distribution
%     tsv_map_uniform = [0.1E-03 0.1E-03 8.60E-03 8.60E-03 1.00E-01 5.00E-02]; %uniform TSV distribution
    
    tsv_map_clustered = [3.525E-03 0.1E-03 1.21E-03 8.16E-03 1.00E-01 5.00E-02]; %clustered TSV distribution
    tsv_map_uniform = [0.1E-03 0.1E-03 7.55E-03 7.55E-03 1.00E-01 5.00E-02]; %uniform TSV distribution
           
    metal_layers = [4];  % Design Parameter 3, values: 3, 4, 8
    
    metal_p = [18e-9 18e-9]; % wire resistivity
    metal_ar_3 = [1.8 1.8 0.4 1.8 1.8 0.4];
    metal_ar_4 = [1.8 1.8 1.8 0.4 1.8 1.8 1.8 0.4];
	metal_ar_8 = [1.8 1.8 1.8 0.4 1.8 1.8 1.8 0.4 1.8 1.8 1.8 0.4 1.8 1.8 1.8 0.4];

%     metal_pitch_3 = [160e-9 360e-9 30e-6 160e-9 360e-9 30e-6]*2;
%     metal_pitch_4 = [160e-9 160e-9 360e-9 30e-6 160e-9 160e-9 360e-9 30e-6]*2;
%     metal_pitch_8 = [160e-9 160e-9 160e-9 160e-9 160e-9 160e-9 360e-9 30e-6 160e-9 160e-9 160e-9 160e-9 160e-9 160e-9 360e-9 30e-6]*2;
%     
%     metal_thick_3 = [144e-9 324e-9 7e-6 144e-9 324e-9 7e-6];
%     metal_thick_4 = [144e-9 144e-9 324e-9 7e-6 144e-9 144e-9 324e-9 7e-6];
%     metal_thick_8 = [144e-9 144e-9 144e-9 144e-9 144e-9 144e-9 324e-9 7e-6 144e-9 144e-9 144e-9 144e-9 144e-9 144e-9 324e-9 7e-6];

    metal_pitch_3 = [160e-9 560e-9 39.5e-6 160e-9 560e-9 39.5e-6]*2;
    metal_pitch_4 = [160e-9 560e-9 560e-9 39.5e-6 160e-9 560e-9 560e-9 39.5e-6]*2;
    metal_pitch_8 = [160e-9 160e-9 160e-9 160e-9 160e-9 160e-9 560e-9 39.5e-6 160e-9 160e-9 160e-9 160e-9 160e-9 160e-9 560e-9 39.5e-6]*2;
    
    metal_thick_3 = [144e-9 324e-9 7e-6 144e-9 324e-9 7e-6];
    metal_thick_4 = [144e-9 144e-9 324e-9 7e-6 144e-9 144e-9 324e-9 7e-6];
    metal_thick_8 = [144e-9 144e-9 144e-9 144e-9 144e-9 144e-9 324e-9 7e-6 144e-9 144e-9 144e-9 144e-9 144e-9 144e-9 324e-9 7e-6];

    via_R_3 = [0.4253 0.1890 0 0.4253 0.1890 0]*450;
    via_R_4 = [0.4253 0.4253 0.1890 0 0.4253 0.4253 0.1890 0]*450;
    via_R_8 = [0.4253 0.4253 0.4253 0.4253 0.4253 0.4253 0.1890 0 0.4253 0.4253 0.4253 0.4253 0.4253 0.4253 0.1890 0]*450;
    
    via_N_3 = [4e9 8e8 1e5 4e9 8e8 1e5]/45;
    via_N_4 = [4e9 4e9 8e8 1e5 4e9 4e9 8e8 1e5]/45;
    via_N_8 = [4e9 4e9 4e9 4e9 4e9 4e9 8e8 1e5 4e9 4e9 4e9 4e9 4e9 4e9 8e8 1e5;]/45;
    
    chip_TSV_Nbundle = [1]; %1 or 25
    
    %scaled powers
    % RRAM
    chip_size = readvars(ip_file_name, 'Sheet', block_level_specs_sheet, 'Range', 'C9:C9'); %units: m
    x_TSV = readvars(ip_file_name, 'Sheet', block_level_specs_sheet, 'Range', 'C10:C10'); %m
    pwr_logic = readvars(ip_file_name, 'Sheet', block_level_specs_sheet, 'Range', 'C11:C11'); % W
    pwr_mem = readvars(ip_file_name, 'Sheet', block_level_specs_sheet, 'Range', 'C12:C12'); % W

    % ADC variables
    x_margin_adc = readvars(ip_file_name, 'Sheet', block_level_specs_sheet, 'Range', 'C16:C16');
    y_margin_adc = readvars(ip_file_name, 'Sheet', block_level_specs_sheet, 'Range', 'C17:C17');
    nADC = readvars(ip_file_name, 'Sheet', block_level_specs_sheet, 'Range', 'C18:C18');
    nyADC = readvars(ip_file_name, 'Sheet', block_level_specs_sheet, 'Range', 'C19:C19');
    nxADC = readvars(ip_file_name, 'Sheet', block_level_specs_sheet, 'Range', 'C20:C20');
    block_dimension_adc = readvars(ip_file_name, 'Sheet', block_level_specs_sheet, 'Range', 'C21:C21');
    y_pitch_adc = readvars(ip_file_name, 'Sheet', block_level_specs_sheet, 'Range', 'C22:C22');
    x_pitch_adc = readvars(ip_file_name, 'Sheet', block_level_specs_sheet, 'Range', 'C23:C23');
    per_ADC_power = readvars(ip_file_name, 'Sheet', block_level_specs_sheet, 'Range', 'C24:C24');
    x_dim_adc = readvars(ip_file_name, 'Sheet', block_level_specs_sheet, 'Range', 'C25:C25');
    pool_gb_xsize_adc = readvars(ip_file_name, 'Sheet', block_level_specs_sheet, 'Range', 'C26:C26');
    y_dim_pool = readvars(ip_file_name, 'Sheet', block_level_specs_sheet, 'Range', 'C27:C27');
    y_dim_gb = readvars(ip_file_name, 'Sheet', block_level_specs_sheet, 'Range', 'C28:C28');
    tsv_xsize_adc = readvars(ip_file_name, 'Sheet', block_level_specs_sheet, 'Range', 'C29:C29');
    pool_power = readvars(ip_file_name, 'Sheet', block_level_specs_sheet, 'Range', 'C30:C30');
    gb_power = readvars(ip_file_name, 'Sheet', block_level_specs_sheet, 'Range', 'C31:C31');


    % MEM variables
    x_margin_MEM = readvars(ip_file_name, 'Sheet', block_level_specs_sheet, 'Range', 'C34:C34');
    y_margin_MEM = readvars(ip_file_name, 'Sheet', block_level_specs_sheet, 'Range', 'C35:C35');
    nMEM = readvars(ip_file_name, 'Sheet', block_level_specs_sheet, 'Range', 'C36:C36');
    nyMEM = readvars(ip_file_name, 'Sheet', block_level_specs_sheet, 'Range', 'C37:C37');
    nxMEM = readvars(ip_file_name, 'Sheet', block_level_specs_sheet, 'Range', 'C38:C38');
    block_dimension_mem = readvars(ip_file_name, 'Sheet', block_level_specs_sheet, 'Range', 'C39:C39');
    y_pitch_mem = readvars(ip_file_name, 'Sheet', block_level_specs_sheet, 'Range', 'C40:C40');
    x_pitch_mem = readvars(ip_file_name, 'Sheet', block_level_specs_sheet, 'Range', 'C41:C41');
    per_MEM_power = readvars(ip_file_name, 'Sheet', block_level_specs_sheet, 'Range', 'C42:C42');
    tsv_xsize_mem = readvars(ip_file_name, 'Sheet', block_level_specs_sheet, 'Range', 'C43:C43');
    x_dim_mem = readvars(ip_file_name, 'Sheet', block_level_specs_sheet, 'Range', 'C44:C44');

    die1_map = [];

    chip(1).Xsize = chip_size;
    chip(1).Ysize = chip_size;

    chip(1).xl = (system.pkg.Xsize - chip(1).Xsize)/2 ;
    chip(1).yb = (system.pkg.Ysize - chip(1).Ysize)/2 ;

    chip(1).c4.px = c4_pitch(1);
    chip(1).c4.py = c4_pitch(1);
    chip(1).c4.d = c4_dia(1);
    chip(1).c4.h = c4_dia(1);
    
    chip(1).tsv_map = tsv_map_clustered;
    chip(1).TSV.Nbundle = chip_TSV_Nbundle(1);

    %Memory (RRAM) power map definition
    chip(1).power = pwr_mem + pwr_logic;
%   chip(1).map = [];
    mem_map = logic_power_map_gen(x_margin_MEM, y_margin_MEM, nyMEM, nxMEM, block_dimension_mem, y_pitch_mem, x_pitch_mem, per_MEM_power);
    B = logic_power_map_gen((x_dim_mem/2 + x_margin_MEM), y_margin_MEM, nyMEM, nxMEM, block_dimension_mem, y_pitch_mem, x_pitch_mem, per_MEM_power);
    mem_map = [mem_map ; B];

    %Logic (ADC) power map definition
    logic_map = logic_power_map_gen(x_dim_mem + x_margin_MEM*2 + x_margin_adc, y_margin_adc, nyADC, nxADC, block_dimension_adc, y_pitch_adc, x_pitch_adc, per_ADC_power);
    A = logic_power_map_gen((x_dim_mem + x_margin_MEM*2 + x_dim_adc/2 + pool_gb_xsize_adc + x_margin_adc), y_margin_adc, nyADC, nxADC, block_dimension_adc, y_pitch_adc, x_pitch_adc, per_ADC_power);
    logic_map = [logic_map ; A];
%     P1 = [(x_dim_adc/2) 0 (pool_gb_xsize_adc/2) y_dim_pool pool_power 0];
    GB1 = [(x_dim_adc/2) 0.1e-3 (pool_gb_xsize_adc/2) y_dim_gb gb_power 0];
%     P2 = [(x_dim_adc/2 + pool_gb_xsize_adc/2 + tsv_xsize_adc) (y_dim_gb) (pool_gb_xsize_adc/2) y_dim_pool pool_power 0];
    GB2 = [(x_dim_adc/2 + pool_gb_xsize_adc/2 + tsv_xsize_adc) 0.1e-3 (pool_gb_xsize_adc/2) y_dim_gb gb_power 0];
    logic_map = [logic_map ; GB1 ; GB2];
    chip(1).map = [mem_map ; logic_map];
    die1_map = readmatrix('./3DCIM/baselinemap.csv'); %Bottom

    chip(1).Xsize = 0.0337+1e-4;
    chip(1).Ysize = 0.0337+1e-4;
        system.pkg.Xsize = chip(1).Xsize+0.0158;
    system.pkg.Ysize = chip(1).Ysize+0.093;


    chip(1).power = 1.91E+01;
    chip(1).map = [die1_map];
    chip(1).blk_name = cell(38880+38880, 1);
    chip(1).blk_name(:) = cellstr('');
    chip(1).blk_num = [38880+38880];
    system.version = 0;
    
    for k = 1:1:length(chip_TSV_Nbundle)
        chip(1).TSV.Nbundle = chip_TSV_Nbundle(k);
        for i = 1:1:length(ubump_pitch)
            chip(1).ubump.px = ubump_pitch(i);
            chip(1).ubump.py = ubump_pitch(i);
            chip(1).ubump.d = ubump_dia(1);
            chip(1).ubump.h = ubump_dia(1);

            for j = 1:1:length(tsv_diameter)
                chip(1).TSV.d = tsv_diameter(j);
                chip(1).TSV.px = tsv_pitch(j);
                
                for m = 1:1:length(metal_layers)
                    chip(1).Metal.N = [metal_layers(m) metal_layers(m)];
                    chip(1).Metal.p = metal_p; % wire resistivity
                    switch (metal_layers(m))
                        case 3
                            chip(1).Metal.ar = metal_ar_3;

                            chip(1).Metal.pitch = metal_pitch_3;
                            chip(1).Metal.thick = metal_thick_3;

                            chip(1).Via.R = via_R_3;
                            chip(1).Via.N = via_N_3;
                        case 4
                            chip(1).Metal.ar = metal_ar_4;

                            chip(1).Metal.pitch = metal_pitch_4;
                            chip(1).Metal.thick = metal_thick_4;

                            chip(1).Via.R = via_R_4;
                            chip(1).Via.N = via_N_4;
                        case 8
                            chip(1).Metal.ar = metal_ar_8;

                            chip(1).Metal.pitch = metal_pitch_8;
                            chip(1).Metal.thick = metal_thick_8;

                            chip(1).Via.R = via_R_8;
                            chip(1).Via.N = via_N_8;
                    end

                    fprintf('\n\nDie size: %12.3e m\n', chip_size);
                    fprintf('Die area: %12.3e m2\n', chip(1).Xsize*chip(1).Ysize);
                    fprintf('Power for Logic: %12.3e W\n', pwr_logic);
                    fprintf('Power for Memory: %12.3e W\n', pwr_mem);
                    fprintf('Total stack power: %12.3e W\n', chip(1).power);
                    fprintf('Chip TSV Nbundle: %12.3e m\n', chip(1).TSV.Nbundle);
                    fprintf('ubump pitch (x and y): %12.3e m\n', chip(1).ubump.px);
                    fprintf('ubump dimeter: %12.3e m\n', chip(1).ubump.d);
                    fprintf('TSV diameter: %12.3e m\n', chip(1).TSV.d);
                    fprintf('TSV pitch (x and y): %12.3e m\n', chip(1).TSV.px);
                    fprintf('TSV height: %12.3e m\n', chip(1).TSV.thick);
                    fprintf('Number of metal layers: %12.3e m\n', chip(1).Metal.N);

                    %% main running script
                    power_noise_sim(system, chip);
                end
            end
        end
    end
end