function [A, C, VImark, extVar] = ResCapExtract(system, chip, cap, var, type)
    %% the element in conductive/inductive matrix C
    extVar = 0;
    for ii = 1 : system.chip.N
        IOmap = chip(ii).type == type;
        Ncur = sum(sum(double(IOmap)));
        extVar = Ncur * chip(ii).N + extVar;
    end
    %% 2 layer of package
    extVar = extVar + system.pkg.Ny * (system.pkg.Nx - system.chip.N)*2 + ...
                      system.pkg.Nx * (system.pkg.Ny - 1)*2;
    % the first part is for domain seperation
    
    %%%%%%%%%%%%%%%%%check back this portion if you have
    %%%%%%%%%%%%%%%%%singularity%%%%%%%%%specially important for multiple
    %%%%%%%%%%%%%%%%%bridges%%%%%
        for ii = 1 : system.Nbridge
            xl = system.interbox(ii,1);
            xr = system.interbox(ii,2);
            yb = system.interbox(ii,3);
            yt = system.interbox(ii,4);
            extVar = extVar - (xr-xl+1)*2 - (yt-yb+1)*2;
        end 
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%                
    
    %% BGA part
    IOmap = floor(system.pkg.type/10) == type;
    Ncur = sum(sum(double(IOmap)));
    extVar = Ncur + extVar;
    
    %% package-level decaps
%     Carray_len = size(system.pkg.decap, 1);
%     extVar = extVar + Carray_len * 2;    
    Carray_len = sum(sum(system.pkg.IsCap));
    extVar = extVar + Carray_len * 2;    
    
    %% board spreading, board decaps (L and C), VRM L & C
    Ndecap = size(system.board.decap, 1);
    extVar = extVar + (1 + 2*Ndecap)*system.chip.N; % '2' is for 
    VImark = ones(var+extVar, 1);
    
    %% the element will be augmented to matrix A
    row = zeros(var*7, 1);
    col = zeros(var*7, 1);
    val = zeros(var*7, 1);
    
    crow = zeros(extVar*7, 1);
    ccol = zeros(extVar*7, 1);
    cval = zeros(extVar*7, 1);
    
    cpointer = 1;
    pointer = 1;   
    Pext = 1;
    
    %on-die matrix build
    for ii = 1 : system.chip.N
        IOmap = chip(ii).type == type;        
        for k = 1 : chip(ii).N
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
                             LineOrient*const + ... % two metal layers
                             (k-1)*const*2 + ... % multi-die coordinating
                             id_offset; % multi-chip coordinating                        
                        
                        if LineOrient == 0                           
                            frontId = id + 1;
                            bottomId = id + const;
                            via_R = viaR/area;
                            
                            if i < chip(ii).Nx
                                row(pointer) = id;
                                col(pointer) = frontId;
                                temp = rou*x2./(thick_L.^2./ar_L) ./( gridy./pitch_L);
                                val(pointer) = sum(1./temp);
                                pointer = pointer + 1;
                            end
                            row(pointer) = id;
                            col(pointer) = bottomId;
                            val(pointer) = 1/via_R;
                            pointer = pointer + 1;

                            crow(cpointer) = id;
                            ccol(cpointer) = id;
                            cval(cpointer) = cap(id);
                            cpointer = cpointer + 1;
                            
                        else
                            frontId = id + chip(ii).Nx;                            
                            if j < chip(ii).Ny
                                row(pointer) = id;
                                col(pointer) = frontId;
                                temp = rou*y2./(thick_V.^2./ar_V) ./( gridx./pitch_V);
                                val(pointer) = sum(1./temp);
                                pointer = pointer + 1;
                            end
                            if IOmap(j,i) == 1
                                
                                if k < chip(ii).N && (chip(ii).Xmesh(i) < chip(ii).tsv_map(1) || ...
                                        chip(ii).Xmesh(i) > chip(ii).tsv_map(1) + chip(ii).tsv_map(3) || ...
                                        chip(ii).Ymesh(j) > chip(ii).tsv_map(2) + chip(ii).tsv_map(4) || ...
                                        chip(ii).Ymesh(j) < chip(ii).tsv_map(2))
                                        extVar = extVar - 1;
                                        continue;
                                end
                                
                                bI = var + Pext;
                                VImark(bI) = 0;
                                Pext = Pext + 1;
                                
                                if k == chip(ii).N
                                    [indX, indY] = chip2pkgId(chip(ii).Xmesh(i), chip(ii).Ymesh(j), chip(ii), system.pkg);
                                    bottomId = system.chip.numV + indX + (indY - 1)*system.pkg.Nx;
                                    via_R = chip(ii).ubump.R_map(j, i);
                                    via_L = chip(ii).ubump.L_map(j, i);
                                else
                                    bottomId = id + const;
                                    via_R = chip(ii).TSV.R;
                                    via_L = chip(ii).TSV.L;
                                end

                                %% add the current into equation
                                row(pointer) = id;
                                col(pointer) = bI;
                                val(pointer) = 1;
                                pointer = pointer + 1;                                

                                row(pointer) = bottomId;
                                col(pointer) = bI;
                                val(pointer) = -1;
                                pointer = pointer + 1;                                 
                                %% add the current branch equation
                                row(pointer) = bI;
                                col(pointer) = id;
                                val(pointer) = -1;
                                pointer = pointer + 1;              

                                row(pointer) = bI;
                                col(pointer) = bottomId;
                                val(pointer) = 1;
                                pointer = pointer + 1;   

                                row(pointer) = bI;
                                col(pointer) = bI;
                                val(pointer) = via_R;
                                pointer = pointer + 1;                        

                                crow(cpointer) = bI;
                                ccol(cpointer) = bI;
                                cval(cpointer) = via_L;
                                cpointer = cpointer + 1;                                             
                            end                            
                        end                        
                    end
                end
            end
        end
    end
        
    const = system.pkg.Nx * system.pkg.Ny;
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
                    Lx = system.pkg.Ls*x2*((system.pkg.N/4)/(system.pkg.N/4-1));
                    Ly = system.pkg.Ls*y2*((system.pkg.N/4)/(system.pkg.N/4-1));
                else
                    Rx = system.pkg.Rs*x2;
                    Ry = system.pkg.Rs*y2;
                    Lx = system.pkg.Ls*x2;
                    Ly = system.pkg.Ls*y2;
                end
                
                if i < system.pkg.Nx && (system.pkg.domain(j, i) == system.pkg.domain(j, i+1))
                    if bridge_flagX ~= 1
                        eI = var + Pext;     
                        VImark(eI) = 0;                    
                        Pext = Pext + 1;                    
                        %KCL
                        row(pointer) = id;
                        col(pointer) = eI;
                        val(pointer) = 1;
                        pointer = pointer + 1;

                        row(pointer) = Eid;
                        col(pointer) = eI;
                        val(pointer) = -1;
                        pointer = pointer + 1;

                        row(pointer) = eI;
                        col(pointer) = id;
                        val(pointer) = -1;
                        pointer = pointer + 1;              

                        row(pointer) = eI;
                        col(pointer) = Eid;
                        val(pointer) = 1;
                        pointer = pointer + 1;   

                        row(pointer) = eI;
                        col(pointer) = eI;
                        val(pointer) = Rx;
                        pointer = pointer + 1;                        

                        crow(cpointer) = eI;
                        ccol(cpointer) = eI;
                        cval(cpointer) = Lx;
                        cpointer = cpointer + 1;
                    end
                end    
                if j < system.pkg.Ny
                    if bridge_flagY ~= 1
                        nI = var + Pext;
                        VImark(nI) = 0;  
                        Pext = Pext + 1;                    
                        %KCL
                        row(pointer) = id;
                        col(pointer) = nI;
                        val(pointer) = 1;
                        pointer = pointer + 1;

                        row(pointer) = Nid;
                        col(pointer) = nI;
                        val(pointer) = -1;
                        pointer = pointer + 1;

                        %% add the current branch equation
                        row(pointer) = nI;
                        col(pointer) = id;
                        val(pointer) = -1;
                        pointer = pointer + 1;              

                        row(pointer) = nI;
                        col(pointer) = Nid;
                        val(pointer) = 1;
                        pointer = pointer + 1;   

                        row(pointer) = nI;
                        col(pointer) = nI;
                        val(pointer) = Ry;
                        pointer = pointer + 1;                        

                        crow(cpointer) = nI;
                        ccol(cpointer) = nI;
                        cval(cpointer) = Ly;
                        cpointer = cpointer + 1; 
                    end
                end
                
                if k == 1
                    if INTER_FLAG ~= 1
                        bottomId = id + const;                    
                        row(pointer) = id;
                        col(pointer) = bottomId;
                        scale = system.pkg.Xsize * system.pkg.Ysize / area;
                        val(pointer) = 1/(system.pkg.ViaR*scale);
                        pointer = pointer + 1;    
                    end
                    
                    if system.bridge_decap > 0 && INTER_FLAG == 1 && (system.bridge_ground == 1 && system.bridge_power == 1)
                        crow(cpointer) = id;
                        ccol(cpointer) = id;
                        cval(cpointer) = system.bridge_decap*area*2;
                        cpointer = cpointer + 1;
                    end
                else
                    if floor(system.pkg.type(j,i)/10) == type
                        bottomId = var - system.chip.N + system.pkg.domain(j, i);
                        bI = var + Pext;
                        VImark(bI) = 0;  
                        Pext = Pext + 1;
                        %% add the current into equation
                        row(pointer) = id;
                        col(pointer) = bI;
                        val(pointer) = 1;
                        pointer = pointer + 1;  
                        
                        row(pointer) = bottomId;
                        col(pointer) = bI;
                        val(pointer) = -1;
                        pointer = pointer + 1;                         

                        %% add the current branch equation
                        row(pointer) = bI;
                        col(pointer) = id;
                        val(pointer) = -1;
                        pointer = pointer + 1;              

                        row(pointer) = bI;
                        col(pointer) = bottomId;
                        val(pointer) = 1;
                        pointer = pointer + 1;   

                        row(pointer) = bI;
                        col(pointer) = bI;
                        val(pointer) = system.BGA.R;
                        pointer = pointer + 1;                        

                        crow(cpointer) = bI;
                        ccol(cpointer) = bI;
                        cval(cpointer) = system.BGA.L;
                        cpointer = cpointer + 1;                                                
                    end
                end
            end
        end
    end

    %% surface mounted decaps
    for k = 1
        for j = 1:system.pkg.Ny
            for i = 1:system.pkg.Nx
                if system.pkg.IsCap(j,i) == 0
                    continue;
                end
                if(i>1) 
                    x1 = system.pkg.Xmesh(i) - system.pkg.Xmesh(i-1);
                else
                    x1 = 0;
                end

                if(i<system.pkg.Nx) && (system.pkg.domain(j, i) == system.pkg.domain(j, i+1))
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
                
                pkgcap = system.pkg.decap(1)*area*2;
                induct = system.pkg.decap(2)/(2*area);
                res = system.pkg.decap(3)/(2*area);
        
                Iid = var + Pext;
                VImark(Iid) = 0;  
                Pext = Pext + 1;
                Vid = var + Pext;
                Pext = Pext + 1;

                % kcl
                row(pointer) = id;
                col(pointer) = Iid;
                val(pointer) = 1;
                pointer = pointer + 1;

                % kvl
                row(pointer) = Iid;
                col(pointer) = id;
                val(pointer) = -1;
                pointer = pointer + 1;              

                row(pointer) = Iid;
                col(pointer) = Vid;
                val(pointer) = 1;
                pointer = pointer + 1;        

                row(pointer) = Iid;
                col(pointer) = Iid;
                val(pointer) = res;
                pointer = pointer + 1;                        

                crow(cpointer) = Iid;
                ccol(cpointer) = Iid;
                cval(cpointer) = induct;
                cpointer = cpointer + 1; 

                % inductance and capacitance constraints
                row(pointer) = Vid;
                col(pointer) = Iid;
                val(pointer) = -1;
                pointer = pointer + 1;                        

                crow(cpointer) = Vid;
                ccol(cpointer) = Vid;
                cval(cpointer) = pkgcap;
                cpointer = cpointer + 1;       
            end    
        end
    end
  
    %% board decap
    for j = 1:system.chip.N
        id = var - system.chip.N + j;  
        for i = 1:Ndecap
            pkgcap = system.board.decap(i, 1)*2;
            induct = system.board.decap(i, 2)/2;
            res = system.board.decap(i, 3)/2;
            
            Iid = var + Pext;
            Pext = Pext + 1;
            VImark(Iid) = 0;
            Vid = var + Pext;
            Pext = Pext + 1;

            % kcl
            row(pointer) = id;
            col(pointer) = Iid;
            val(pointer) = 1;
            pointer = pointer + 1;

            % kvl
            row(pointer) = Iid;
            col(pointer) = id;
            val(pointer) = -1;
            pointer = pointer + 1;              

            row(pointer) = Iid;
            col(pointer) = Vid;
            val(pointer) = 1;
            pointer = pointer + 1;        

            row(pointer) = Iid;
            col(pointer) = Iid;
            val(pointer) = res;
            pointer = pointer + 1;                        

            crow(cpointer) = Iid;
            ccol(cpointer) = Iid;
            cval(cpointer) = induct;
            cpointer = cpointer + 1; 

            row(pointer) = Vid;
            col(pointer) = Iid;
            val(pointer) = -1;
            pointer = pointer + 1;                        

            crow(cpointer) = Vid;
            ccol(cpointer) = Vid;
            cval(cpointer) = pkgcap;
            cpointer = cpointer + 1;  
        end
    %% board parasitics
        Iid = var + Pext;
        Pext = Pext + 1;
        VImark(Iid) = 0;  
        % kcl
        row(pointer) = id;
        col(pointer) = Iid;
        val(pointer) = 1;
        pointer = pointer + 1;

        % kvl FOR vrm l AND R
        row(pointer) = Iid;
        col(pointer) = id;
        val(pointer) = -1;
        pointer = pointer + 1;    

        row(pointer) = Iid;
        col(pointer) = Iid;
        val(pointer) = system.board.Rs;
        pointer = pointer + 1;         

        crow(cpointer) = Iid;
        ccol(cpointer) = Iid;
        cval(cpointer) = system.board.Ls;
        cpointer = cpointer + 1;
    end
    
    fprintf('Extra parameters expected: %d, Actually added: %d\n', extVar, Pext-1);
    
    VImark = VImark(1:var+extVar);
    
    row = row(1:pointer-1,1);
    col = col(1:pointer-1,1);
    val = val(1:pointer-1,1);
    A = sparse(row, col, val, var+extVar, var+extVar);
    
    crow = crow(1:cpointer-1,1);
    ccol = ccol(1:cpointer-1,1);
    cval = cval(1:cpointer-1,1);
    C = sparse(crow, ccol, cval, var+extVar, var+extVar);  
end

