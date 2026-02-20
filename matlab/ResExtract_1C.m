function [A, D] = ResExtract(system, chip, var, type)
%% this function is to extract all the resistor information
% and build resistance only matrix
    row = zeros(var*7, 1);
    col = zeros(var*7, 1);
    val = zeros(var*7, 1);
    pointer = 1;
    tiermap = findmap(system,chip);

    for ii = 1 : system.chip.N
        for k = 1 : chip(ii).N
            IOmap = chip(ii).type == type;
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
            for LineOrient = [1, 0]
                % 0 means vertical line and 1 means horizontal line
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
                            y2 = 0;
                        end
                        
                        gridy = (y1+y2)/2;                
                        area = gridx*gridy;                        
                        
                        
                        id = (j-1)*chip(ii).Nx + i + ... % in-plane coordinating
                             LineOrient*const + ... % interleaved coordinating
                             (k-1)*const*2 + ... % multi-die coordinating
                             id_offset; % multi-chip coordinating
                         
                        if LineOrient == 0
                            % Check if you're at the top die
                            if (k==1)
                                % Bottom id needs to be bottom layer
                                frontId = id + 1;
                                bottomId = id + const*3;
                            % At the bottom die
                            else
                                % Originally at the 3rd layer, need to be
                                % at 2nd layer
                                id = id - const;
                                frontId = id + 1;
                                bottomId = id + const;
                            end

                            via_R = viaR/area;
                            
                            if i < chip(ii).Nx
                                row(pointer) = id;
                                col(pointer) = frontId;
                                temp = rou*x2./(thick_L.^2./ar_L) ./( gridy./pitch_L);
                                val(pointer) = 1 / (sum(1./temp));
                                a = 1 / (sum(1./temp));
                                pointer = pointer + 1;
                                % Check if the dies are not overlapping
                                if tiermap(j,i) == 0 && k==2
                                    % Remove connection
                                    val(pointer-1) = 1e12;
                                end

                            end
                            row(pointer) = id;
                            col(pointer) = bottomId;
                            val(pointer) = via_R;
                            % if k==2
                            %     val(pointer) = 1000;
                            % end
                            pointer = pointer + 1;
                           
                            % Remove connecting where the dies are not
                            % overlapping
                            if tiermap(j,i) == 1 && k==1
                                val(pointer-1) = 1e12;
                            elseif tiermap(j,i) == 0 && k==2
                                val(pointer-1) = 1e12;
                            end

                            % Adding BEOL via connections between 4 and 2
                            if k>1
                                % Moving id to 3 and 4
                                id = id + const;
                                frontId = id + 1;
                                bottomId = id + const;

                                % We only need to add the bottom id
                                row(pointer) = id;
                                col(pointer) = bottomId;
                                val(pointer) = via_R;
                                %val(pointer) = 1000;
                                pointer = pointer + 1;

                                % Remove connecting where the dies are not
                                % overlapping
                                if tiermap(j,i) == 0
                                    val(pointer-1) = 1e12;
                                end
                            end

                        % Line orientation = 1
                        else
                            % Check if you're at the top die
                            if (k==1)
                                % Need to be at the bottom layer
                                id = id + const*2;
                            % Check if you're at the bottom layer
                            else
                                % Need to be 
                                id = id - const;
                            end

                            frontId = id + chip(ii).Nx;                            
                            if j < chip(ii).Ny
                                row(pointer) = id;
                                col(pointer) = frontId;
                                temp = rou*y2./(thick_V.^2./ar_V) ./( gridx./pitch_V);
                                val(pointer) = 1 / (sum(1./temp)); % sum of two parallel resistances
                                a = 1 / (sum(1./temp));
                                % Check if you're at the bottom die and that
                                % the dies are not overlapping
                                if tiermap(j,i) == 1 && k==1
                                    val(pointer) = 1e12;
                                elseif tiermap(j,i) == 0 && k==2
                                    val(pointer) = 1e12;
                                end
                                
                                pointer = pointer + 1;
                            end

                            if IOmap(j,i) == 1

                                    % Need to reset the id to what it is
                                    % originally
                                id = (j-1)*chip(ii).Nx + i + ... % in-plane coordinating
                                     LineOrient*const + ... % interleaved coordinating
                                     (k-1)*const*2 + ... % multi-die coordinating
                                     id_offset; % multi-chip coordinating

                                if k == chip(ii).N
                                    [indX, indY] = chip2pkgId(chip(ii).Xmesh(i), chip(ii).Ymesh(j), chip(ii), system.pkg);
                                    bottomId = system.chip.numV + indX + (indY - 1)*system.pkg.Nx;
                                    via_R = chip(ii).ubump.R_map(j,i);
                                    
                                    row(pointer) = id;
                                    col(pointer) = bottomId;
                                    val(pointer) = via_R;
                                    pointer = pointer + 1; 
                                else
                                    %Adding the TSVs
                                    %Need to move id to connect the 1st
                                    %and 3rd layer
                                    id = id - const;
                                    bottomId = id + 2*const;
                                    via_R = chip(ii).TSV.R;

                                    if chip(ii).Xmesh(i)>= chip(ii).tsv_map(1) && ...
                                        chip(ii).Xmesh(i)<= chip(ii).tsv_map(1) + chip(ii).tsv_map(3) && ...
                                        chip(ii).Ymesh(j)<= chip(ii).tsv_map(2) + chip(ii).tsv_map(4) && ...
                                        chip(ii).Ymesh(j) >= chip(ii).tsv_map(2)
                                        row(pointer) = id;
                                        col(pointer) = bottomId;
                                        val(pointer) = via_R;
                                        pointer = pointer + 1;

                                        % Remove connection if the 2 dies
                                        % are not overlapping
                                        if tiermap(j,i) == 0
                                            % Remove connection to high
                                            % resistance value
                                            val(pointer-1) = 1e12;
                                        end

                                    end
                                end
                            end                            
                        end
                    end
                end
            end
        end
    end

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
    %%create sparese matrices
    row = row(1:pointer-1,1);
    col = col(1:pointer-1,1);
    val = val(1:pointer-1,1);
    A = sparse(row, col, 1./val, var, var);
    row = var-system.chip.N+1 : var;
    col = var-system.chip.N+1 : var;
    val = system.board.Rs*ones(system.chip.N,1);
    D = sparse(row, col, 1./val, var, var);
end