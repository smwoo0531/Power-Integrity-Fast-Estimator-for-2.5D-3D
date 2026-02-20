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
% *****************02/14/2023 Ankit*****************************************
% ***implemented 3-D integration such as TSV and u-bump-based 3-Dxls

%% clear caches

clc
clear
close all
for iii = 0

    period = 1e-9;
    edge = 0.5e-3;
    system.bridge.FLAG = iii;
    system.chip.N = 1;
    system.bridge_ground = 0;
    system.bridge_power = 0;


    chip(1).N = 1;

%%%%%%%% sweep parameters%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    ubump_dia = [12]*1e-6;
    c4_dia = [50]*1e-6;

    chip_TSV_Nbundle = [1 2 4 6 9 16 25]; %% <- important
    chip_TSV_Nbundle = [ 4]; %% <- important
    ubump_pitch = [50]*1e-6; 
    c4_pitch = [100]*1e-6;    

    %if system.structure == 2
    %    chip(1).ubump.scale = 1;
    %else
    %    chip(1).ubump.scale = 1/chip(1).TSV.Nbundle;
    %end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    %% Input excel details

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%chip /package sizes and positions
    system.pkg.Xsize = 3.5e-3; 
    system.pkg.Ysize = 3.5e-3;
    chip(1).Xsize = 2.5e-3; %chip x dimension; y dimension below
    chip(1).Ysize = 2.5e-3;
% package and chip positions (lower-left corner);
    chip(1).xl = 5e-4;
    chip(1).yb = 5e-4;
    %chip(1).xl = (system.pkg.Xsize - chip(1).Xsize)/2 ;
    %chip(1).yb = (system.pkg.Ysize - chip(1).Ysize)/2 ;   



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% bump pitches
    chip(1).c4.px = 240e-6;
    chip(1).c4.py = 200e-6;
    %chip(1).ubump.px = 120e-6;
    %chip(1).ubump.py = 240e-6;
    chip(1).ubump.px = 240e-6;
    chip(1).ubump.py = 200e-6; %% <----- 50um *2 
    system.BGA.px = 240e-6;
    system.BGA.py = 200e-6;

    chip(1).TSV.px = 240E-6; % it's not working. F2B -> ubump pitch= TSV pitch, F2F -> C4 pitch=TSV pitch
    chip(1).TSV.py = 200E-6; 
% bump placement style, vdd/vss first
    chip(1).TSV.vdd_first = 0;
    chip(1).TSV.staggered = 1 ;
    chip(1).TSV.xoffset = 0e-6; % temporary / need to add a function
    chip(1).TSV.yoffset = 0e-6; % temporary / need to add a function

    chip(1).TSV.yoffset_power = 100e-6; % temporary / need to add a function
    chip(1).TSV.yoffset_ground = 100e-6; % temporary / need to add a function

    chip(1).ubump.vdd_first = 0;
    chip(1).ubump.staggered = 0 ;   
    chip(1).ubump.xoffset = 0e-6; % temporary / need to add a function
    chip(1).ubump.yoffset = 0e-6; % temporary / need to add a function

    chip(1).c4.vdd_first = 0; %% <---issue!! must be resolved!!
    chip(1).c4.staggered = 1;

    system.BGA.vdd_first = 0;
    system.BGA.staggered = 1;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% System structure 
    system.version = 0;
    system.TOV = 0;
    system.structure = 3; % 0 = org ,1= f2b , 2= f2f 3=2d+interposer
    chip.intermetal.usage = 1;
    chip(1).f2b_top = 0;    
    system.debug_id = 0;
    system.debug_power = 0;
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %blk_num is for splitting the power maps of each die
    % format: xl corner, yb corner, x size, y size, power, decap %

% Vary Power map
%    if  chip(1).N == 2 
%       chip(1).power(1) = 2; %  above chip Die (TOP) 
%       chip(1).power(2) = 2 ; % powerbelow chip (BOTTOM) power
%    else 
        %chip(1).power = [0.7];
        chip(1).power(1) = 8.081;
%    end

    %% chip(1).power = [0.7]; %total power dissipation of each die (single power)

    bank_power = 0;
    bank_map = [];
    %chip(1).map = [0.4e-3 0.5e-3 1.2e-3 1.6e-3  chip(1).power 0.05];
    %chip(1).map = [0.4e-3 0.5e-3 1.2e-3 1.6e-3  0.5 0.05;
    %               0e-3 0e-3 0.4e-3 0.5e-3 0.1 0.05;
    %                ];


    % Unknown <- need to check 
    % Testing imported memory map
    %die1_map = [];
    %die2_map = [];
    %chip(1).blk_num = [0 0];
    %die1_map = [0.4e-3 0.5e-3 1.2e-3 1.6e-3  chip(1).power(1) 0.05;                     ];
    %die1_map = [  0.25e-3 0.25e-3 2e-3 2e-3  chip(1).power(1) 0.05                 ];
    %die1_map = [  0.25e-3 0.25e-3 2e-3 2e-3  chip(1).power(1) 0.05  ];
    die1_map = [  0.25e-3 0.25e-3 2e-3 2e-3  chip(1).power(1) 0.05  ];

    %die2_map = [  0.25e-3 0.25e-3 2e-3 2e-3  chip(1).power(2) 0.05                 ];
    chip(1).blk_num = [1];

    %chip(1).map = [die1_map; die2_map];
    chip(1).map = [die1_map];
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % Added settings by Taehoon
    %%% 1) manual R for ubump, TSV, C4, BGA and so on
    
    %%% 2) mesh grid
    % top die / bottom die diff
    %%% 3) mesh R calulation
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    chip(1).mesh_grid.custom = 1;
    system.inter_grid.custom = 0;
    system.pkg_grid.custom = 0;
    %% px-> vertical mesh pitch, py-> horizontal mesh pitch
    %chip(1).mesh_grid.px = chip(1).ubump.px/4;
    %chip(1).mesh_grid.py= chip(1).ubump.py/4;
    %chip(1).mesh_grid.px = 240e-6/4;
    chip(1).mesh_grid.px = 240e-6/4;
    chip(1).mesh_grid.py=  200e-6/4;


    chip.mesh_correlation =1;
    chip.mesh_L_scaling = 1;
    chip.mesh_V_scaling =2; % default for accurcy
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    system.inter_mesh_correlation = 0;
    system.inter_grid.px = chip(1).mesh_grid.px;
    system.inter_grid.py = chip(1).mesh_grid.py;
    
    %system.inter_grid.px = 25e-6;
    %system.inter_grid.py = 25e-6;
    
    system.pkg_grid.px = chip(1).mesh_grid.px;
    system.pkg_grid.py = chip(1).mesh_grid.py;
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    chip(1).TSV.custom.para = 0;
    chip(1).TSV.custom.R = 1e-12;

    chip(1).TOV.custom.para = 1;
    chip(1).TOV.custom.R = 1e-12;
    
    chip(1).c4.custom.para = 0;
    chip(1).c4.custom.R = 1e-12;
    
    chip(1).ubump.custom.para = 0;
    chip(1).ubump.custom.R = 1e-12;
    %chip(1).ubump.custom.para = 1;
    %chip(1).ubump.custom.R = 0.04;

    chip(1).HB.custom.R   = 1;
    chip(1).HB.custom.R = 1e-12;    
    system.TSV.custom.para = 1;
    system.TSV.custom.R = 1e-12;
    
    system.BGA.custom.para = 1;
    system.BGA.custom.R = 1e-12;

    % TOV, HB


    
    
    %% Interposer parameters
    %system.intermetal.rho = 1e-12;
    system.intermetal.rho = 1.68e-8;
    system.intermetal.ar = 0.011111;
    system.intermetal.pitch = 100e-6;
    system.intermetal.thick = 1e-6;

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %% die2
%    chip(1).die(2).Metal.N = [2];
%    %chip(1).die(2).Metal.p = [1e-12]; % wire resistivity
%    chip(1).die(2).Metal.p = [1.68e-8]; % wire resistivity
%    chip(1).die(2).Metal.ar = [0.011111 0.011111];
%    chip(1).die(2).Metal.pitch = [100e-6 100e-6]; % need to confirm
%    chip(1).die(2).Metal.thick = [1e-6 1e-6];
%    chip(1).die(2).Via.R = [3.14E-07 3.14E-07]; % need to confirm
%    chip(1).die(2).Via.N = [500 500]*4;


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%555

    %% for Chip # 1 parameters %%
    chip(1).meshlvl = 0;
    
    % Two metal layer
    %chip(1).Metal.N = [2];
    %chip(1).Metal.p = [60e-9]; % wire resistivity
    %chip(1).Metal.ar = [0.2667 0.025];
    %chip(1).Metal.pitch = [48e-6 200e-6]; % need to confirm
    %chip(1).Metal.thick = [0.8e-6 2e-6];
    %chip(1).Via.R = [0.00278 0.00278 ];
    %chip(1).Via.N = [500 500]*4;
    %chip(1).cap_per = [0.05];
    %chip(1).cap_th = [0.9e-9]; %capacitance effective thicknee (used for capacitance value calculation)

    %%%%% Four metal layer Configuration (Technology: FreePDK45) %%%%%
    chip(1).Metal.N = [4];

    % Wire resistivity
    %chip(1).Metal.p = [240e-9]; % Narrow Mesh
    %chip(1).Metal.p = [120e-9]; % Default
    %chip(1).Metal.p = [60e-9]; % High Util.
    chip(1).Metal.p = [120e-9];     

    % Aspect ratio: AR = Thickness / Width
    %chip(1).Metal.ar = [0.112 0.32 0.32 0.055]; % Default
    chip(1).Metal.ar = [0.224 0.64 0.64 0.11]; % Narrow Mesh
    %chip(1).Metal.ar = [0.056 0.16 0.16 0.0275]; % High Util.

    % Mesh pitch
    %chip(1).Metal.pitch = [10e-6 10e-6 10e-6 120e-6]; % % Default & High Util.
    chip(1).Metal.pitch = [5e-6 5e-6 5e-6 60e-6]; % Narrow Mesh

    % Mesh thickness
    chip(1).Metal.thick = [0.28e-6 0.8e-6 0.8e-6 2e-6];

    % Via resistance at each layer
    chip(1).Via.R = [3 1 1 0.5];

    % Number of vias at each layer
    chip(1).Via.N = [562500 562500 562500 110000]; % Default & Narrow Mesh
    %chip(1).Via.N = [562500 562500 562500 110000]*2; % High Util.

    chip(1).cap_per = [0.05];
    chip(1).cap_th = [0.9e-9]; %capacitance effective thicknee (used for capacitance value calculation)

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    %chip metal/via
    %metal_layers = [2];  % Design Parameter 4, values: 3, 4, 8
    %metal_p = [60e-9]; % wire resistivity
    %metal_ar = [0.2667 0.02];
    %metal_pitch = [48e-6 250e-6];
    %metal_thick = [0.8e-6 2e-6];
    %via_R = [0.00278 0.00278 ];
    %via_N = [500 500]*4;



  
    % chip(1).tsv_map = [lower left x, upper right x, lower left y, upper right y, 5.00E-02]
    chip(1).tsv_map = [0 0 chip(1).Xsize chip(1).Ysize ]; %distributed TSV distribution

    chip(1).Tp = period; %period
    chip(1).Tr = 0.4e-9; %rise time
    chip(1).Tf = 0.4e-9; %fall time
    chip(1).Tc = 0.2e-9; %fall time
    
    chip(1).blk_name = cell(12, 1);
    chip(1).blk_name(:) = cellstr('');
    chip(1).blk_name(3) = cellstr('Cache');
    chip(1).blk_name(5) = cellstr('Core');
    chip(1).blk_name(8) = cellstr('Core');
    chip(1).name = cellstr('CPU'); 
    



    %% for bump/TSV %%
    chip(1).TSV.d = 4e-6; %TSV diameter
    chip(1).TSV.contact = 0.45*1e-6^2; %resistance per unit area
    chip(1).TSV.liner = 0.2e-6;
    chip(1).TSV.mu = 1.257e-6;
    %chip(1).TSV.rou = 80e-9; % resistivity of copper
    chip(1).TSV.rou = 1.68e-8; % resistivity of copper
    chip(1).TSV.thick = 100e-6;
    chip(1).TSV.scale = 1;

    chip(1).c4.rou = 400e-9;
    %chip(1).c4.rou = 1.5e-7;
    chip(1).c4.d = 75e-6;
    chip(1).c4.h = 75e-6;
    chip(1).c4.mu = 1.257e-6;    
    chip(1).c4.Nbundle = 1;
    chip(1).c4.scale = 1;% group bump
    
    chip(1).ubump.rou = 400e-9;
    %chip(1).ubump.rou = 1.5e-7;    
    chip(1).ubump.d = 12e-6;
    chip(1).ubump.h = 12e-6;
    chip(1).ubump.mu = 1.257e-6;
    chip(1).ubump.scale = 1/2; %group bump
    


    system.BGA.rou = 123e-9;
    system.BGA.d = 250e-6;
    system.BGA.h = 150e-6;
    system.BGA.mu = 1.257e-6;
    system.BGA.scale = 1;

    system.TSV.Nbundle = 25;
    system.TSV.d = 4e-6; % TSV diameter
    system.TSV.px = 50e-6; %TSV X pitch (p2p/g2g)
    system.TSV.py = 50e-6; %TSV Y pitch (p2p/g2g)
    system.TSV.contact = 0; %resistance per unit area
    system.TSV.liner = 0.5e-6;
    system.TSV.mu = 1.257e-6;
    system.TSV.rou = 30e-9; % resistivity of copper
    system.TSV.thick = 100e-6;
    system.TSV.scale = 1;



    %% Package parameters
    system.pkg.wire_p = 1e-12;
    system.pkg.N = 4;
    system.pkg.wire_thick = 0.02e-3;
    
    % package decap format: xl, yb, xsize, ysize, c, esl, esr
    system.pkg.decap = [52e-6 5.61e-13*2.5/1.5 541.5e-9/8];
    system.pkg.Rs = 36.685; %unit: ohm/m
    system.pkg.Ls = 2.4e-8; %unit: H/m
    %system.pkg.decap(:,5) = system.pkg.decap(:,5)*2;
    %system.pkg.Cdst = 2e-9*1e4; % F per m^2 
    system.pkg.ViaR = 1e-12;
    system.pkg.ViaN = 1e12;
    system.pkg.mu = 1.257e-6;

    %% board parameters
    system.board.Rs = 1e-12;
    system.board.Ls = 21e-12;
    
    %board decap format: c, esl, esr
    system.board.decap = [240e-6 19.536e-6 166e-6];



    %%%%%%%%bridge decap%%%%%%%%%%%
    system.bridge_decap = 0; %5 nF/mm2 bridge decap
    system.inter = 0;
    system.emib = 0;
    system.emib_via = 0;
    system.stacked_die = 1; %% <----------------- ?????????????????????????? 

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

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






    %% for system level parameters
    system.tran = 0; % transient analysis or not;
    system.write = 0; %whether to write the data or not
    system.gif = 0; % whether to draw the gifs along simulations
    system.draw = 1; %whether to draw the noise map for transient analysis
    system.tranplot = 0; %whether to draw the noise map for transient analysis
    system.drawP = 1; %display the current requirement map
    system.drawC = 0; %display the decap distribution
    system.drawM = 1; %display the mesh or not
    system.clamp = 0;
    system.range = [0 5];
    system.skip = 0; % skip running but read and plot data directly
    system.TR_FLAG = 1; %whether to use trapezoid scheme
    system.ubump.uniform = 1; %0 means pattern tuned by c4; 1 means uniform
    
    system.T = 2e-9; %transient simulation time 
    system.dt = 0.025e-9; %simulation step, TR scheme is stable for 0.1e-9, which is pretty optimized
    system.Vdd.val = 1.1; %VDD value for of VRM


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

   







    chip(1).blk_name = cell(38880+38880, 1);
    chip(1).blk_name(:) = cellstr('');
    embedded_die_count = 1; % # of dies embedded in bottom tier10

    %% block layout specs
    cell_count = 4;
    sim_case = [1];

    substrate_thick = 1.00E-05; %units: m
    tsv_height = substrate_thick; %units: m
    tsv_diameter = 1.00E-06; %units: m  % Design Parameter 2
    tsv_pitch = 2.00E-06; %units: m


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    




%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    for k = 1:1:length(chip_TSV_Nbundle)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            chip(1).TSV.Nbundle = chip_TSV_Nbundle(k);
            %if system.structure == 2
            %     chip(1).ubump.scale = 1/8;
            %else
            %     chip(1).ubump.scale = 1/chip(1).TSV.Nbundle;
            %end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                    for i = 1:1:length(ubump_pitch)
                        %chip(1).ubump.px = ubump_pitch(i);
                        %chip(1).ubump.py = ubump_pitch(i);
                        %chip(1).ubump.d = ubump_dia(1);
                        %chip(1).ubump.h = ubump_dia(1);
            
                        for j = 1:1:length(c4_pitch)
                            %chip(1).c4.px = c4_pitch(j);
                            %chip(1).c4.py = c4_pitch(j);
                            %chip(1).c4.d = c4_dia(j);
                            %chip(1).c4.h = c4_dia(j);
 
                            %chip(1).Metal.N = [metal_layers metal_layers];
                            %chip(1).Metal.p = [metal_p metal_p]; 
                            %chip(1).Metal.ar = [metal_ar metal_ar];
                            %chip(1).Metal.pitch = [metal_pitch metal_pitch];
                            %chip(1).Metal.thick = [metal_thick metal_thick];
                            %chip(1).Via.R = [via_R via_R];
                            %chip(1).Via.N = [via_N via_N];
                            if  chip(1).N == 2        
                                chip(1).Metal.N = [chip(1).Metal.N chip(1).die(2).Metal.N];
                                chip(1).Metal.p = [metal_p chip(1).die(2).Metal.p]; 
                                chip(1).Metal.ar = [metal_ar chip(1).die(2).Metal.ar];
                                chip(1).Metal.pitch = [metal_pitch chip(1).die(2).Metal.pitch];
                                chip(1).Metal.thick = [metal_thick chip(1).die(2).Metal.thick];
                                chip(1).Via.R = [via_R chip(1).die(2).Via.R];
                                chip(1).Via.N = [via_N chip(1).die(2).Via.N];
                            end

                               
                            
                                fprintf('\n\nDie X size: %12.3e m\n', chip(1).Xsize);
                                fprintf('\n\nDie Y size: %12.3e m\n', chip(1).Ysize);
                                fprintf('Die area: %12.3e m2\n', chip(1).Xsize*chip(1).Ysize);
                              %  fprintf('Power for Logic: %12.3e W\n', chip(1).power(2));
                                fprintf('Power for Memory: %12.3e W\n', chip(1).power(1));
                              %  fprintf('Total stack power: %12.3e W\n', (chip(1).power(1) + chip(1).power(2)));
                                fprintf('Total stack power: %12.3e W\n', (chip(1).power(1)));
                                fprintf('Chip TSV Nbundle: %12.3e\n', chip(1).TSV.Nbundle);
                                fprintf('ubump pitch (x and y): %12.3e m\n', chip(1).ubump.px);
                                fprintf('ubump dimeter: %12.3e m\n', chip(1).ubump.d);
                                fprintf('C4 diameter: %12.3e m\n', chip(1).c4.d);
                                fprintf('C4 pitch (x and y): %12.3e m\n', chip(1).c4.px);
                                %fprintf('Number of metal layers: %12.3e\n', chip(1).Metal.N);
                                fprintf('TSV dimeter: %12.3e m\n', chip(1).TSV.d);
            
                                %% main running script
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%5%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                                %%% power_noise_sim_3D_test(system, chip);


                                    %this is the main PDN simulator
                                    system.type.P = 1; system.type.G = 2; 
                                    t_start = tic;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%5%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                                    %% [system, chip] = calParasitics(system, chip);


                                   % function [system_, chip_] = calParasitics(system, chip)
                                      %  for i = 1:system.chip.N
                                      %      chip(i).c_gate = 3.9*8.85e-12./chip(i).cap_th*2;
                                      %      for j = 1:chip(i).N
                                      %          st = sum(chip(i).blk_num(1:j-1))+1;
                                      %          ed = st + chip(i).blk_num(j) - 1;
                                      %          if ed >= st
                                      %              chip(i).map(st:ed, 6) = chip(i).map(st:ed, 6)*chip(i).c_gate(j)*2;           
                                      %          end
                                      %      end
                                      %  end
                                    
                             %           if system.inter == 1 || system.emib_via == 1 || system.stacked_die == 1
                             %               rou = system.TSV.rou;
                             %               h = system.TSV.thick;
                             %               d = system.TSV.d;
                             %               liner = system.TSV.liner;
                             %               mu = system.TSV.mu;
                             %               pitch = system.TSV.px/2;
                             %               if system.TSV.custom.para == 1
                             %                   system.TSV.R = system.TSV.custom.R;
                             %               else
                             %                   system.TSV.R =  (rou*h/(0.25*pi*(d-2*liner)^2) + system.TSV.contact/(0.25*pi*(d-2*liner)^2))/system.TSV.Nbundle;
                             %               end 
                             %               Lself = mu*h/(2*pi)*log(2*pitch/d);
                             %               Lmutual = 4*0.199*mu*h*log(1+1.0438*h/sqrt(pitch^2/2))-4*0.199*mu*h*log(1+1.0438*h/pitch);
                             %               system.TSV.L = (Lself + Lmutual)/system.TSV.Nbundle;
                             %           end    
                                        
                                        for i = 1:system.chip.N
                                            %if chip(i).N > 1
                                                rou = chip(i).TSV.rou;
                                                h = chip(i).TSV.thick;
                                                d = chip(i).TSV.d;
                                                liner = chip(i).TSV.liner;
                                                mu = chip(i).TSV.mu;
                                                pitch = chip(i).TSV.px/2;
                                                if chip(1).TSV.custom.para == 1
                                                    chip(i).TSV.R =  chip(i).TSV.custom.R  ;
                                                else 
                                                   % chip(i).TSV.R =  ((rou*h/(0.25*pi*(d-2*liner)^2) + chip(i).TSV.contact/(0.25*pi*d^2))/chip(i).TSV.Nbundle) * chip(i).ubump.scale;
                                                   chip(i).TSV.R =  ((rou*h/(0.25*pi*(d-2*liner)^2) + chip(i).TSV.contact/(0.25*pi*d^2))/chip(i).TSV.Nbundle) *  chip(i).TSV.scale;
                                                end
                                                
                                                Lself = mu*h/(2*pi)*log(1+2.84*h/(pi*(d/2)));
                                                Lmutual = 4*0.199*mu*h*log(1+1.0438*h/sqrt(pitch^2/2))-4*0.199*mu*h*log(1+1.0438*h/pitch);
                                                %% need to fix
                                                chip(i).TSV.L = (Lself + Lmutual)/system.TSV.Nbundle;
                                    
                                                % Repeat for TOVs - this is only true for the reconstituted
                                                % tier case
                                                if system.TOV == 1
                                                    rou = chip(i).TOV.rou;
                                                    h = chip(i).TOV.thick;
                                                    d = chip(i).TOV.d;
                                                    liner = chip(i).TOV.liner;
                                                    mu = chip(i).TOV.mu;
                                                    pitch = chip(i).TOV.px/2;
                                                    if chip(i).TOV.custom.para == 1
                                                        chip(i).TOV.R = chip(i).TOV.custom.R ;
                                                    else
                                                        chip(i).TOV.R =  (rou*h/(0.25*pi*(d-2*liner)^2) + chip(i).TOV.contact/(0.25*pi*d^2))/chip(i).TOV.Nbundle;
                                                    end
                                                    
                                                    % change if running transient
                                                    Lself = mu*h/(2*pi)*log(1+2.84*h/(pi*(d/2)));
                                                    Lmutual = 4*0.199*mu*h*log(1+1.0438*h/sqrt(pitch^2/2))-4*0.199*mu*h*log(1+1.0438*h/pitch);
                                                    chip(i).TOV.L = (Lself + Lmutual)/chip(i).TOV.Nbundle;
                                                end
                                    
                                            %end
                                            %% for microbump
                                            rou = chip(i).ubump.rou;
                                            h = chip(i).ubump.h;
                                            d = chip(i).ubump.d;
                                            mu = chip(i).ubump.mu;
                                            pitch = chip(i).ubump.px/2;

                                            if chip(i).ubump.custom.para == 1
                                                chip(i).ubump.R =  chip(i).ubump.custom.R;
                                                chip(i).HB.R =  chip(i).HB.custom.R;
                                            else 
                                                chip(i).ubump.R =  rou*h/(0.25*pi*d^2)*chip(i).ubump.scale;
                                                chip(i).HB.R =  rou*h/(0.25*pi*d^2);
                                            end
                                    
                                            Lself = mu*h/(2*pi)*log(2*pitch/d)*chip(i).ubump.scale;
                                            Lmutual = 0; %4*0.199*mu*h*log(1+1.0438*h/sqrt(pitch^2/2))-4*0.199*mu*h*log(1+1.0438*h/pitch);
                                            chip(i).ubump.L = (Lself + Lmutual); 
                                            
                                            rou = chip(i).c4.rou;
                                            h = chip(i).c4.h;
                                            d = chip(i).c4.d;
                                            mu = chip(i).c4.mu;
                                            pitch = chip(i).c4.px/2;

                                            if chip(i).c4.custom.para == 1
                                               chip(i).c4.R =  chip(i).c4.custom.R;    
                                            else
                                                chip(i).c4.R =  rou*h/(0.25*pi*d^2)*chip(i).c4.scale/chip(i).c4.Nbundle;
                                            end
                                    
                                            Lself = mu*h/(2*pi)*log(2*pitch/d)*chip(i).c4.scale;
                                            Lmutual = 0; %0.199*mu*h*log(1+1.0438*h/sqrt(pitch^2/2))-4*0.199*mu*h*log(1+1.0438*h/pitch);
                                            chip(i).c4.L = (Lself + Lmutual)/chip(i).c4.Nbundle;
                                                    
                                            if system.inter == 1
                                                if chip(i).ubump.custom.para == 1 
                                                    chip(i).ubump.R = chip(i).ubump.custom.R;
                                                else 
                                                    chip(i).ubump.R = chip(i).c4.R/chip(i).c4.Nbundle + chip(i).ubump.R + system.TSV.R;
                                                end 
                                                chip(i).ubump.L = chip(i).c4.L/chip(i).c4.Nbundle + chip(i).ubump.L + system.TSV.L;
                                            elseif system.bridge_ground == 1
                                                if chip(i).c4.custom.para == 1
                                                    chip(i).c4.R =      chip(i).c4.custom.R;                                              
                                                else
                                                    chip(i).c4.R = chip(i).c4.R/chip(i).c4.Nbundle;
                                                end
                                                chip(i).c4.L = chip(i).c4.L/chip(i).c4.Nbundle;
                                            end
                                        end
                                        
                                    %    system.pkg.Cdst = 1.1*8.85e-12*system.pkg.N*0.5*2/system.pkg.wire_thick;
                                    
                                        %% for BGA
                                        rou = system.BGA.rou;
                                        h = system.BGA.h;
                                        d = system.BGA.d;
                                        mu = system.BGA.mu;
                                        pitch = system.BGA.px/2;
                                        if system.BGA.custom.para == 1
                                            system.BGA.R = system.BGA.custom.R;
                                        else
                                            system.BGA.R =  rou*h/(0.25*pi*d^2)*system.BGA.scale;
                                        end
                                    
                                        Lself = mu*h/(2*pi)*log(1+2.84*h/(pi*(d/2)));
                                        Lmutual = 4*0.199*mu*h*log(1+1.0438*h/sqrt(pitch^2/2))-4*0.199*mu*h*log(1+1.0438*h/pitch);
                                        system.BGA.L = Lself + Lmutual;       
                                    
                                    %     decap = sum(system.board.decap(:,1)); 
                                    %     induct = 1/sum(1./system.board.decap(:,2));
                                    %     res = 1/sum(1./system.board.decap(:,3));
                                    %     system.board.decap = [decap, induct, res];
                                        
                                    %    system_ = system;
                                    %    chip_ = chip;
                               %     end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%




                                    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%5
                                    chip = TSVGen(system, chip);                                
                                    chip = ubumpGen(system, chip);
                                    chip = c4Gen(system,chip);
                                    system = BGAGen(system);
                                
                                    [system, chip] = mesh(system, chip, system.drawM);
                                    system.Tmesh = meshTran(system.T, system.dt);
                                
                                    [var, system, chip] = initial_IR(system, chip);

                                    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                                    %% current debug   
                                    %% current_full  = dumpCurrent(system, chip, var, system.drawP);
                                    current_full  = dumpCurrent(system, chip, var, system.drawP);




                                    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                                    % build R only matrix
                                    if system.skip == 1
                                        tranplot_one_time_cmp(system, chip, system.tranplot);
                                    else
                                        if system.tran == 0                
                                            %this is for IR drop simulations
                                            i = 1;
                                            x = zeros(var, 2);
                                            for type = [system.type.P, system.type.G]
                                                if system.version == 1
                                                    [A, D] = ResExtract_1C(system, chip, var, type);
                                                elseif system.version == 2
                                                    [A, D] = ResExtract_2(system, chip, var, type);
                                                elseif system.version == 0
                                                    if system.structure == 0 
                                                        [A, D] = ResExtract_baseline(system, chip, var, type);
                                                    elseif  system.structure == 1
                                                        [A, D] = ResExtract_baseline_F2B(system, chip, var, type);
                                                    elseif  system.structure == 2            
                                                        [A, D] = ResExtract_baseline_F2F(system, chip, var, type);
                                                    elseif  system.structure == 3            
                                                        [A, D] = ResExtract_baseline_2D_interposer(system, chip, var, type);
                                                    end
                                                elseif system.version == 3
                                                    [A, D] = ResExtract_1A(system, chip, var, type);
                                                else
                                                    [A, D] = ResExtract_1B(system, chip, var, type);
                                                end
                                                Y = MatrixBuild(A, D, var);
                                                x(:,i) = Noise_solver_ss(Y, current_full);
                                                power_loss(system, var, Y, x(:, i));
                                                i = i + 1;
                                            end
                                            result = draw_map(system, chip, x(:,1), x(:,2), 0, system.write, system.draw);
                                        else
                                            cap_all = dumpCap(system, chip, var, system.drawC);
                                            Tlen = length(system.Tmesh);
                                            for type = [system.type.P, system.type.G]
                                                [A, C, VImark, extVar] = ResCapExtract(system, chip, cap_all, var, type);
                                                Y = MatrixBuild_tran(A, var);
                                                [L, U, P, Q, R] = tranFac(Y, C, system.dt, system.TR_FLAG);
                                                x = VImark * 0;
                                                draw_map_tran(system, chip, x, 0, system.write, system.draw, type);
                                                bprev = tranDumpCurrent(system, chip, current_full, 0, extVar);
                                                perc = 20;
                                                ratio = 20;
                                                for i = 2 : Tlen
                                                    b = tranDumpCurrent(system, chip, current_full, system.Tmesh(i), extVar);
                                                    x = Noise_solver_tran_lu(L, U, P, Q, R, Y, C, b, bprev, x, system.dt, system.TR_FLAG);
                                                    bprev = b; 
                                                    draw_map_tran(system, chip, x, system.Tmesh(i), system.write, system.draw, type);
                                                    if i >= Tlen * ratio/100
                                                        fprintf('simulation %d %% done\n', ratio);
                                                        ratio = ratio + perc;
                                                    end
                                                end
                                            end
                                            tranplot(system, chip, system.tranplot);
                                        end
                                    end
                                    toc(t_start);
                        end
                    end
            end
    end