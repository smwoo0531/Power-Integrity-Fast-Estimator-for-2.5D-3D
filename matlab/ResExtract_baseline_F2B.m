function [A, D] = ResExtract(system, chip, var, type)
%% this function is to extract all the resistor information
% and build resistance only matrix
    row = zeros(var*7, 1);
    col = zeros(var*7, 1);
    val = zeros(var*7, 1);
    pointer = 1;
    %c4count=0;

    % !! chip.intermetal
    if chip.intermetal.usage == 1 

            for ii = 1 : system.chip.N              
                for k = 1 : chip(ii).N
                    IOmap = chip(ii).type == type;
                    IOmapc4 = chip(ii).typec4 == type;
                    IOmapTSV = chip(ii).typeTSV == type;  
      
                    id_offset = 0;
                    for kk = 1:ii-1
                        id_offset = id_offset + chip(kk).numV;
                    end
                    Nmetal = chip(ii).Metal.N(k);            
                    rou = chip(ii).Metal.p(k);
                    offset = sum(chip(ii).Metal.N(1:k-1));
                    ar = chip(ii).Metal.ar(offset + 1 : offset + Nmetal);            
                    pitch = chip(ii).Metal.pitch(offset + 1 : offset + Nmetal);
                    thick = chip(ii).Metal.thick(offset + 1 : offset + Nmetal);
                    viaR = chip(ii).Via.R(offset + 1 : offset + Nmetal);
                    viaN = chip(ii).Via.N(offset + 1 : offset + Nmetal);
                    
                    viaR = sum(viaR./viaN)*chip(ii).Xsize*chip(ii).Ysize;
                    %The layer with either vertical or lateral lines
                    %top layer always has a vertical line
                    pitch_V = pitch(2:2:end);
                    pitch_L = pitch(1:2:end);
                    thick_V = thick(2:2:end);
                    thick_L = thick(1:2:end);
                    ar_V = ar(2:2:end);
                    ar_L = ar(1:2:end);
                    const = chip(ii).Nx * chip(ii).Ny;
        
        
                    for LineOrient = [0, 1]
                        % 0 means lateral line and 1 means vertical line
    
                        for j = 1:chip(ii).Ny
                            mesh_counter_i = 1;
                            mesh_counter_i_max = (chip(ii).ubump.px/chip(ii).mesh_grid.px) ;
    
    
                            for i = 1:chip(ii).Nx
                                if(i>1) 
                                    x1 = chip(ii).Xmesh(i)-chip(ii).Xmesh(i-1);
                                else
                                    x1 = 0;
                                end
        
                                if(i<chip(ii).Nx)
                                    x2 = chip(ii).Xmesh(i+1) - chip(ii).Xmesh(i);
                                else
                                    x2 = 0;
                                end    
                                gridx = (x1+x2)/2;
        
                                if(j>1) 
                                    y1 = chip(ii).Ymesh(j)-chip(ii).Ymesh(j-1);
                                else
                                    y1 = 0;
                                end
        
                                if(j<chip(ii).Ny)
                                    y2 = chip(ii).Ymesh(j+1) - chip(ii).Ymesh(j);
                                else
                                    y2 = 0;
                                end
                                
                                gridy = (y1+y2)/2;  
                                if chip(ii).mesh_grid.custom == 1
                                    gridx_temp = gridx *chip(ii).ubump.px/chip(ii).mesh_grid.px / chip.mesh_V_scaling;
                                    area = gridx_temp *gridy;
    
                                else
                                    area = gridx*gridy;                        
                                end
                                if k == chip(ii).N
                                    id = (j-1)*chip(ii).Nx + i + ... % in-plane coordinating
                                         LineOrient*const + ... % interleaved coordinating
                                         (k-1)*const*2 + ... % multi-die coordinating
                                         const + ... % interposer
                                         id_offset; % multi-chip coordinating                                    

                                else
                                    id = (j-1)*chip(ii).Nx + i + ... % in-plane coordinating
                                         LineOrient*const + ... % interleaved coordinating
                                         (k-1)*const*2 + ... % multi-die coordinating
                                         id_offset; % multi-chip coordinating
                                end

                                %% test
                                if system.debug_id == 1
                                    fprintf('Chip %d , LineOrient: %d , id: %d\n', k, LineOrient, id);
                                end

                                %%
                                if LineOrient == 0                           
                                    frontId = id + 1;
                                    bottomId = id + const;
                                    via_R = viaR/area;
                                    
                                    if i < chip(ii).Nx
                                        row(pointer) = id;
                                        col(pointer) = frontId;
                                        temp = rou*x2./(thick_L.^2./ar_L) ./( gridy./pitch_L);
                                        val(pointer) = 1 / (sum(1./temp));
                                        pointer = pointer + 1;

                                    end
                                    row(pointer) = id;
                                    col(pointer) = bottomId;
                                    val(pointer) = via_R;
                                    pointer = pointer + 1;
                                else
                                    frontId = id + chip(ii).Nx;                            
                                    if j < chip(ii).Ny
                                        row(pointer) = id;
                                        col(pointer) = frontId;
                                        if (type == 1 && mesh_counter_i ==  mesh_counter_i_max/2+1) || (type == 2 && mesh_counter_i == 1)

                                              %% temporarly considering org mesh grid -> it should be fixed
                                            if chip(ii).mesh_grid.custom == 1
                                                gridx_temp = gridx *chip(ii).ubump.px/chip(ii).mesh_grid.px / chip.mesh_V_scaling;
                                                temp = rou*y2./(thick_V.^2./ar_V) ./( gridx_temp./pitch_V)/chip.mesh_V_scaling;
                                            else
                                                temp = rou*y2./(thick_V.^2./ar_V) ./( gridx./pitch_V)/chip.mesh_V_scaling;
                                            end
                                            
                                        else
                        
                                            temp = 1e12;
                                       
                                        end 

    
                                        val(pointer) = 1 / (sum(1./temp));
                                        a = 1 / (sum(1./temp));
                                        pointer = pointer + 1;
                                    end
                                    % For c4 bumps
                                    if k == chip(ii).N
                                         if IOmapc4(j,i) == 1

                                            [indX, indY] = chip2pkgId(chip(ii).Xmesh(i), chip(ii).Ymesh(j), chip(ii), system.pkg);
                                            bottomId = system.chip.numV + indX + (indY - 1)*system.pkg.Nx;
                                            via_R = chip(ii).c4.R_map(j,i);
                                            %c4count=c4count+1;
                                            %c4count
                                            %% test
                                             if system.debug_id == 1                            
                                                 fprintf('c4 , id: %d , bottomId: %d\n',  id, bottomId);
                                             end
                                            %% 
                                            row(pointer) = id;
                                            col(pointer) = bottomId;
                                            val(pointer) = via_R;
                                            pointer = pointer + 1;
                                        end
                                    else
                                          if IOmap(j,i) == 1

                                                bottomId = id + const; %% <-need to confirm

                                                
                                                via_R = chip(ii).ubump.R_map(j,i);
       
                                                row(pointer) = id;
                                                col(pointer) = bottomId;
                                                val(pointer) = via_R;
                                                pointer = pointer + 1;   

                                            %% test
                                             if system.debug_id == 1                          
                                                fprintf('ubump , id: %d , bottomId: %d\n',  id, bottomId);
                                             end
                                            %% 
                                          end
                                    end
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

                                       % 1)  ubump map connection: 
                                       % top die/topmetal <->intermesh  


    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    
                                end  
                                 %type
                                 %i
                                 %j
                                 %mesh_counter_i
                                if mesh_counter_i >= mesh_counter_i_max 
                                    mesh_counter_i=1;
                                else 
                                    mesh_counter_i = mesh_counter_i+1;
                                end    
                            end
                        end
                    end
                  
               %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%mesh debug
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        
        
            %%%% inter metal
                    % modifed (top die)
                    % intermetal.usage==1 && k==1
                    if (chip.intermetal.usage == 1 ) && (k ~= chip(ii).N)


                        % 2) gen hor inter mesh
                        rou = system.intermetal.rho;
                        ar = system.intermetal.ar;
                        pitch = system.intermetal.pitch;
                        thick = system.intermetal.thick;
                        pitch_V = pitch;
                        pitch_L = pitch;
                        thick_V = thick;
                        thick_L = thick;
                        ar_V = ar;
                        ar_L = ar;
                        const = chip(ii).Nx * chip(ii).Ny;


                         for j = 1:chip(ii).Ny
        
                            for i = 1:chip(ii).Nx
                                if(i>1) 
                                    x1 = chip(ii).Xmesh(i)-chip(ii).Xmesh(i-1);
                                else
                                    x1 = 0;
                                end
                
                                if(i<chip(ii).Nx)
                                    x2 = chip(ii).Xmesh(i+1) - chip(ii).Xmesh(i);
                                else
                                    x2 = 0;
                                end    
                                gridx = (x1+x2)/2;
                
                                if(j>1) 
                                    y1 = chip(ii).Ymesh(j)-chip(ii).Ymesh(j-1);
                                else
                                    y1 = 0;
                                end
                
                                if(j<chip(ii).Ny)
                                    y2 = chip(ii).Ymesh(j+1) - chip(ii).Ymesh(j);
                                else
                                    %% debug: infi value
                                    %y2 = 0;
                                     y2 = 1e-12;
                                end
                
                                gridy = (y1+y2)/2;                
                
                                id = (j-1)*chip(ii).Nx + i + ... % in-plane coordinating
                                     k*const*2  + ... % multi-die coordinating
                                     id_offset; % multi-chip coordinating
                                %% test
                                if system.debug_id == 1
                                   fprintf('Interposer , id: %d\n',  id);
                                end
                                %% 


                                %fprintf('id: %d, i: %d, j: %d\n',  id, i , j);



                                %east neighbor
                                frontId = id + 1;
                                if i < chip(ii).Nx
                                    row(pointer) = id;



                                    col(pointer) = frontId;
                                    temp = rou*y2./(thick_V.^2./ar_V) ./( gridx./pitch_V);
                                    val(pointer) = 1 / (sum(1./temp));
                                    pointer = pointer + 1;
     
                                    %%% fprintf('id: %d, frontId: %d, temp: %d\n',  id, frontId, temp);
                
                                end
                                %north neighbor
                                frontId = id + chip(ii).Nx;                            
                                if j < chip(ii).Ny
                                    row(pointer) = id;
                                    col(pointer) = frontId;
                                    temp = rou*y2./(thick_V.^2./ar_V) ./( gridx./pitch_V);
                                    val(pointer) = 1 / (sum(1./temp));
                                    pointer = pointer + 1;
                                    %temp
                                end
                                % 3) tsv map connection:
                                % intemesh <->bottom die bottom mesh
                                % 
                                                                
                                if IOmapTSV(j,i) == 1
            
                                    if chip(ii).Xmesh(i)>= chip(ii).tsv_map(1) && ...
                                             chip(ii).Xmesh(i)<= chip(ii).tsv_map(1) + chip(ii).tsv_map(3) && ...
                                             chip(ii).Ymesh(j)<= chip(ii).tsv_map(2) + chip(ii).tsv_map(4) && ...
                                             chip(ii).Ymesh(j) >= chip(ii).tsv_map(2)
                                         if k ~= chip(ii).N

                                            if chip(ii).f2b_top == 1 
                                                bottomId = id + 2*const; %% <-need to confirm

                                            else % connected to bottom metal
                                                bottomId = id + const; %% <-need to confirm
                                            end

                                            via_R = chip(ii).TSV.R_map(j,i);
                                            %% test
                                            if system.debug_id == 1                            
                                                fprintf('tsv , id: %d , bottomId: %d\n',  id, bottomId);
                                            end
                                            %% 
                                            row(pointer) = id;
                                            col(pointer) = bottomId;
                                            val(pointer) = via_R;
                                            pointer = pointer + 1;    

                                         end
                                    end
                                end


                             end          
        
                         end
                    end
        
                
         
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        
                end
            end





%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            % chip intermetal =0
        else
            for ii = 1 : system.chip.N
                for k = 1 : chip(ii).N
                    IOmap = chip(ii).type == type;
                    IOmapc4 = chip(ii).typec4 == type;
                    % added 
                    IOmapTSV = chip(ii).typeTSV == type;        
        
                    %IOmapTSV = findTSV(system,chip); % Get location of TSVs
        
        
                    id_offset = 0;
                    for kk = 1:ii-1
                        id_offset = id_offset + chip(kk).numV;
                    end
                    Nmetal = chip(ii).Metal.N(k);            
                    rou = chip(ii).Metal.p(k);
                    offset = sum(chip(ii).Metal.N(1:k-1));
                    ar = chip(ii).Metal.ar(offset + 1 : offset + Nmetal);            
                    pitch = chip(ii).Metal.pitch(offset + 1 : offset + Nmetal);
                    thick = chip(ii).Metal.thick(offset + 1 : offset + Nmetal);
                    viaR = chip(ii).Via.R(offset + 1 : offset + Nmetal);
                    viaN = chip(ii).Via.N(offset + 1 : offset + Nmetal);
                    
                    viaR = sum(viaR./viaN)*chip(ii).Xsize*chip(ii).Ysize;
                    %The layer with either vertical or lateral lines
                    %top layer always has a vertical line
                    pitch_V = pitch(2:2:end);
                    pitch_L = pitch(1:2:end);
                    thick_V = thick(2:2:end);
                    thick_L = thick(1:2:end);
                    ar_V = ar(2:2:end);
                    ar_L = ar(1:2:end);
                    const = chip(ii).Nx * chip(ii).Ny;
        
                    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%mesh debug

        
                        for LineOrient = [0, 1]
                            % 0 means lateral line and 1 means vertical line
        
                            for j = 1:chip(ii).Ny
                                mesh_counter_i = 1;
                                mesh_counter_i_max = (chip(ii).ubump.px/chip(ii).mesh_grid.px) ;
        
        
                                for i = 1:chip(ii).Nx
                                    if(i>1) 
                                        x1 = chip(ii).Xmesh(i)-chip(ii).Xmesh(i-1);
                                    else
                                        x1 = 0;
                                    end
            
                                    if(i<chip(ii).Nx)
                                        x2 = chip(ii).Xmesh(i+1) - chip(ii).Xmesh(i);
                                    else
                                        x2 = 0;
                                    end    
                                    gridx = (x1+x2)/2;
            
                                    if(j>1) 
                                        y1 = chip(ii).Ymesh(j)-chip(ii).Ymesh(j-1);
                                    else
                                        y1 = 0;
                                    end
            
                                    if(j<chip(ii).Ny)
                                        y2 = chip(ii).Ymesh(j+1) - chip(ii).Ymesh(j);
                                    else
                                        y2 = 0;
                                    end
                                    
                                    gridy = (y1+y2)/2;  
                                    if chip(ii).mesh_grid.custom == 1
                                        gridx_temp = gridx *chip(ii).ubump.px/chip(ii).mesh_grid.px / chip.mesh_V_scaling;
                                        area = gridx_temp *gridy;
        
                                    else
                                        area = gridx*gridy;                        
                                    end
        
                          
                                    
                                    
                                    id = (j-1)*chip(ii).Nx + i + ... % in-plane coordinating
                                         LineOrient*const + ... % interleaved coordinating
                                         (k-1)*const*2 + ... % multi-die coordinating
                                         id_offset; % multi-chip coordinating
                                    %% test
                                    if system.debug_id == 1
                                        fprintf('Chip %d , LineOrient: %d , id: %d\n', k, LineOrient, id);
                                    end                          
                                    if LineOrient == 0                           
                                        frontId = id + 1;
                                        bottomId = id + const;
                                        via_R = viaR/area;
                                        
                                        if i < chip(ii).Nx
                                            row(pointer) = id;
                                            col(pointer) = frontId;
                                            %if chip(ii).mesh_grid.custom == 1
                                                %gridy_temp = gridy *chip(ii).ubump.py/chip(ii).mesh_grid.py /2;
                                                %gridy_temp
                                            %    temp = rou*x2./(thick_L.^2./ar_L) ./( gridy_temp./pitch_L);
                                            %else
                                                temp = rou*x2./(thick_L.^2./ar_L) ./( gridy./pitch_L);
                                            %end
                                           
                                            val(pointer) = 1 / (sum(1./temp));
                                            pointer = pointer + 1;
                                            %rou
                                            %x2
                                            %thick_L
                                            %ar_L
                                            %gridy
                                            %pitch_L
                                            %temp
                                            %width=thick_L/ar_L;
                                            %effective_width = width* gridy/pitch_L;
                                            %width
                                            %effective_width
                                        end
                                        row(pointer) = id;
                                        col(pointer) = bottomId;
                                        val(pointer) = via_R;
                                        pointer = pointer + 1;
                                        %via_R
                                    else
                                        frontId = id + chip(ii).Nx;                            
                                        if j < chip(ii).Ny
                                            row(pointer) = id;
                                            col(pointer) = frontId;
                                            if (type == 1 && mesh_counter_i ==  mesh_counter_i_max/2+1) || (type == 2 && mesh_counter_i == 1)
                                                %temp = rou*y2./(thick_V.^2./ar_V/) ./( gridx./pitch_V);
        
                                                  %% temporarly considering org mesh grid -> it should be fixed
                                                if chip(ii).mesh_grid.custom == 1
                                                    gridx_temp = gridx *chip(ii).ubump.px/chip(ii).mesh_grid.px / chip.mesh_V_scaling;
                                                    temp = rou*y2./(thick_V.^2./ar_V) ./( gridx_temp./pitch_V)/chip.mesh_V_scaling;
                                                else
                                                    temp = rou*y2./(thick_V.^2./ar_V) ./( gridx./pitch_V)/chip.mesh_V_scaling;
                                                end
            
                                                %temp
                                                %type
                                                %i
                                                %j
                                                %vertical_line_counter = vertical_line_counter +1 ;
                                                
                                            else
                            
                                                temp = 1e12;
                                                
                                            end 
                                            %type
                                            %i
                                            %j
                                            %mesh_counter_i
                                            %rou
                                            %y2
                                            %thick_V
                                            %ar_V
                                            %gridx
                                            %pitch_V
                                            %temp
                                            %width=thick_V/ar_V;
                                            %effective_width = width* gridx/pitch_V;
                                            %width
                                            %effective_width      
        
                                            val(pointer) = 1 / (sum(1./temp));
                                            a = 1 / (sum(1./temp));
                                            pointer = pointer + 1;
                                        end
                                        % For c4 bumps
                                        if IOmapc4(j,i) == 1
                                            if k == chip(ii).N
                                                [indX, indY] = chip2pkgId(chip(ii).Xmesh(i), chip(ii).Ymesh(j), chip(ii), system.pkg);
                                                bottomId = system.chip.numV + indX + (indY - 1)*system.pkg.Nx;
                                                via_R = chip(ii).c4.R_map(j,i);
                                                %c4count=c4count+1;
                                                %c4count
                                                 %% test
                                                 if system.debug_id == 1                          
                                                    fprintf('C4 , id: %d , bottomId: %d\n',  id, bottomId);
                                                 end
                                                 %%                                                
                                                row(pointer) = id;
                                                col(pointer) = bottomId;
                                                val(pointer) = via_R;
                                                pointer = pointer + 1;
                                            end
                                        end
        
        
        
                                        % modifed
                                        if IOmapTSV(j,i) == 1
                                            %if IOmapTSV(j,i) == 1
                
                                             if chip(ii).Xmesh(i)>= chip(ii).tsv_map(1) && ...
                                                         chip(ii).Xmesh(i)<= chip(ii).tsv_map(1) + chip(ii).tsv_map(3) && ...
                                                         chip(ii).Ymesh(j)<= chip(ii).tsv_map(2) + chip(ii).tsv_map(4) && ...
                                                         chip(ii).Ymesh(j) >= chip(ii).tsv_map(2)
                                                 if k ~= chip(ii).N
                                                    if chip(ii).f2b_top == 1 
                                                        bottomId = id + 2*const; %% <-need to confirm
        
                                                    else % connected to bottom metal
                                                        bottomId = id + const; %% <-need to confirm
                                                    end
                                                    
        
                                                    
                                                    %via_R = chip(ii).TSV.R+chip(ii).ubump.R_map(j,i);
                                                    via_R = chip(ii).ubump.R+chip(ii).TSV.R_map(j,i);
                                                    row(pointer) = id;
                                                    col(pointer) = bottomId;
                                                    val(pointer) = via_R;
                                                    pointer = pointer + 1;    
                                                     %% test
                                                     if system.debug_id == 1                          
                                                        fprintf('TSVubump , id: %d , bottomId: %d\n',  id, bottomId);
                                                     end
                                                     %% 
                                                 end
                                            end
                                        end
        
                                    end  
                                     %type
                                     %i
                                     %j
                                     %mesh_counter_i
                                    if mesh_counter_i >= mesh_counter_i_max 
                                        mesh_counter_i=1;
                                    else 
                                        mesh_counter_i = mesh_counter_i+1;
                                    end    
                                end
                            end
                        end
 
               %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%mesh debug
        
        
                end
            end
    end %% end chip.intermetal
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%% 3) package
    const = system.pkg.Nx * system.pkg.Ny;
    numBGA = zeros(system.chip.N, 1);
    for k = 1:2
        for j = 1:system.pkg.Ny
            for i = 1:system.pkg.Nx
                if(i>1) 
                    x1 = system.pkg.Xmesh(i) - system.pkg.Xmesh(i-1);
                else
                    x1 = 0;
                end

                if(i<system.pkg.Nx)
                    x2 = system.pkg.Xmesh(i+1) - system.pkg.Xmesh(i);
                else
                    x2 = 0;
                end    
                gridx = (x1+x2)/2;

                if(j>1) 
                    y1 = system.pkg.Ymesh(j) - system.pkg.Ymesh(j-1);
                else
                    y1 = 0;
                end

                if(j<system.pkg.Ny)
                    y2 = system.pkg.Ymesh(j+1) - system.pkg.Ymesh(j);
                else
                    y2 = 0;
                end

                gridy = (y1+y2)/2;                
                area = gridx*gridy;
                
                id = system.chip.numV + (j-1)*system.pkg.Nx + i + (k-1)*const;
                %% test
                if system.debug_id == 1
                    fprintf('package , id: %d\n',  id);
                end
                %% 
                Eid = id + 1;
                Nid = id + system.pkg.Nx;
                INTER_FLAG = 0;
                bridge_flagX = 0;
                bridge_flagY = 0;
                if system.emib == 1
                    for ii = 1 : system.Nbridge
                        xl = system.interbox(ii,1);
                        xr = system.interbox(ii,2);
                        yb = system.interbox(ii,3);
                        yt = system.interbox(ii,4);
                        if (i == xl-1 || i == xr) &&  (yb <= j && yt >= j) && k == 1
                            bridge_flagX = 1;
                        end
                        if (j == yb - 1 || j == yt) && (xl <= i && xr >= i) && k == 1
                            bridge_flagY = 1;
                        end
                        if (xl <= i && xr >= i && ...
                           yb <= j && yt >= j)
                            INTER_FLAG = 1;
                            break;
                        end
                    end                        
                end
                if INTER_FLAG == 1 && k == 1
                    Rx = system.pkg.Rs*x2*((system.pkg.N/4)/(system.pkg.N/4-1));
                    Ry = system.pkg.Rs*y2*((system.pkg.N/4)/(system.pkg.N/4-1));
                else
                    Rx = system.pkg.Rs*x2;
                    Ry = system.pkg.Rs*y2;
                end
                if k == 1
                    if INTER_FLAG ~= 1
                        bottomId = id + const;                    
                        row(pointer) = id;
                        col(pointer) = bottomId;
                        scale = system.pkg.Xsize * system.pkg.Ysize / area;
                        val(pointer) = system.pkg.ViaR*scale;
                        pointer = pointer + 1;
                    end
                else
                    if floor(system.pkg.type(j,i)/10) == type
                        numBGA(system.pkg.domain(j, i)) = numBGA(system.pkg.domain(j, i))  + 1;
                        bottomId = var - system.chip.N + system.pkg.domain(j, i);
                        row(pointer) = id;
                        col(pointer) = bottomId;
                        val(pointer) = system.BGA.R;
                        pointer = pointer + 1;                        
                    end
                end
                if i < system.pkg.Nx && system.pkg.domain(j, i) == system.pkg.domain(j, i+1)
                    if bridge_flagX ~= 1
                        row(pointer) = id;
                        col(pointer) = Eid;
                        val(pointer) = Rx;
                        pointer = pointer + 1;
                    end
                end    
                if j < system.pkg.Ny
                    if bridge_flagY ~= 1
                        row(pointer) = id;
                        col(pointer) = Nid;
                        val(pointer) = Ry;
                        pointer = pointer + 1;
                    end
                end                
            end
        end
    end
    for i = 1 : system.chip.N
        fprintf('chip %d, BGA number: %d\n', i, numBGA(i));
    end
    %%create sparse matrices
    row = row(1:pointer-1,1);
    col = col(1:pointer-1,1);
    val = val(1:pointer-1,1);
    A = sparse(row, col, 1./val, var, var);
    row = var-system.chip.N+1 : var;
    col = var-system.chip.N+1 : var;
    val = system.board.Rs*ones(system.chip.N,1);
    D = sparse(row, col, 1./val, var, var);
end