function [system, chip] = mesh(system, chip, drawM)
    tic;
    N = system.chip.N;
    system.chip.Xgrid = system.pkg.Xsize;
    system.chip.Ygrid = system.pkg.Ysize;
    for i = 1:N
        if chip(i).mesh_grid.custom == 1
            system.chip.Xgrid = chip(i).mesh_grid.px;
            system.chip.Ygrid = chip(i).mesh_grid.py;
        else 
            system.chip.Xgrid = min(chip(i).ubump.px/2^(1+chip(i).meshlvl), system.chip.Xgrid);
            system.chip.Ygrid = min(chip(i).ubump.py/2^(1+chip(i).meshlvl), system.chip.Ygrid);
        end
    end
        
    xl = min(chip(1:N).xl);
    xr = max([chip(1:N).xl] + [chip(1:N).Xsize]);
    yb = min(chip(1:N).yb);
    yt = max([chip(1:N).yb] + [chip(1:N).Ysize]);
    
    system.box.Nx = round((xr - xl) / system.chip.Xgrid);
    system.box.Ny = round((yt - yb) / system.chip.Ygrid);
    system.box.Xmesh = linspace(xl, xr, system.box.Nx + 1);
    system.box.Ymesh = linspace(yb, yt, system.box.Ny + 1);
    
    if system.pkg_grid.custom == 1
        system.pkg.Xgrid = system.pkg_grid.px;
        system.pkg.Ygrid = system.pkg_grid.py;
    else 
        system.pkg.Xgrid = system.BGA.px/2;
        system.pkg.Ygrid = system.BGA.py/2;
    end
    
    system.pkg.Xmesh = [0:system.pkg.Xgrid:xl, system.box.Xmesh, xr:system.pkg.Xgrid:system.pkg.Xsize];
    system.pkg.Xmesh = unique(system.pkg.Xmesh);
    system.pkg.Ymesh = [0:system.pkg.Ygrid:yb, system.box.Ymesh, yt:system.pkg.Ygrid:system.pkg.Ysize];
    system.pkg.Ymesh = unique(system.pkg.Ymesh);
    fprintf('Meshing Done, Using %.2f seconds\n', toc);

    system.Nbridge = size(system.connect, 1);
    system.interbox = zeros(system.Nbridge , 4);
    for i = 1 : system.Nbridge 
        xl = system.connect(i, 1);
        yb = system.connect(i, 2);
        xr = xl + system.connect(i, 3);
        yt = yb + system.connect(i, 4);
        [~, xlInd] = min(abs(xl - system.pkg.Xmesh));
        [~, xrInd] = min(abs(xr - system.pkg.Xmesh));
        [~, ybInd] = min(abs(yb - system.pkg.Ymesh));
        [~, ytInd] = min(abs(yt - system.pkg.Ymesh));
        system.interbox(i, :) = [xlInd xrInd ybInd ytInd];
    end
    
    system.pkg.Nx = length(system.pkg.Xmesh);
    system.pkg.Ny = length(system.pkg.Ymesh);
    
    system.pkg.type = zeros(system.pkg.Ny, system.pkg.Nx);
    system.pkg.IsCap = ones(system.pkg.Ny, system.pkg.Nx);
    box = [system.pkg.Nx, 0, system.pkg.Ny, 0];


    for i = 1:system.chip.N
        [~, xlInd] = min(abs(chip(i).xl - system.pkg.Xmesh));
        [~, xrInd] = min(abs(chip(i).xl + chip(i).Xsize - system.pkg.Xmesh));
        [~, ybInd] = min(abs(chip(i).yb - system.pkg.Ymesh));
        [~, ytInd] = min(abs(chip(i).yb + chip(i).Ysize - system.pkg.Ymesh));
        box(1) = min(box(1), xlInd);
        box(2) = max(box(2), xrInd);
        box(3) = min(box(3), ybInd);
        box(4) = max(box(4), ytInd);
        chip(i).Xmesh = system.pkg.Xmesh(xlInd:xrInd) - chip(i).xl;
        chip(i).Ymesh = system.pkg.Ymesh(ybInd:ytInd) - chip(i).yb;
        chip(i).Nx = xrInd - xlInd + 1;
        chip(i).Ny = ytInd - ybInd + 1;
        chip(i).type = zeros(chip(i).Ny, chip(i).Nx);
        chip(i).typec4 = zeros(chip(i).Ny, chip(i).Nx);
        chip(i).typeTSV = zeros(chip(i).Ny, chip(i).Nx);

        chip(i).ubump.R_map = ones(chip(i).Ny, chip(i).Nx)*chip(i).ubump.R;
        chip(i).ubump.L_map = ones(chip(i).Ny, chip(i).Nx)*chip(i).ubump.L;  
        chip(i).c4.R_map = ones(chip(i).Ny, chip(i).Nx)*chip(i).c4.R;
        chip(i).c4.L_map = ones(chip(i).Ny, chip(i).Nx)*chip(i).c4.L; 

        %%added
        chip(i).TSV.R_map = ones(chip(i).Ny, chip(i).Nx)*chip(i).TSV.R;
        chip(i).TSV.L_map = ones(chip(i).Ny, chip(i).Nx)*chip(i).TSV.L; 


        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%5
        for j = 1:chip(i).ubump.P + chip(i).ubump.G
            x = chip(i).ubump.loc(j,1);
            y = chip(i).ubump.loc(j,2);
            type = chip(i).ubump.loc(j,3);
            [~, xind] = min(abs(x + chip(i).xl - system.pkg.Xmesh));
            [~, yind] = min(abs(y + chip(i).yb - system.pkg.Ymesh));
            INTER_FLAG = 0;
            for ii = 1 : system.Nbridge 
                xl = system.interbox(ii,1);
                xr = system.interbox(ii,2);
                yb = system.interbox(ii,3);
                yt = system.interbox(ii,4);
                if (xl <= xind && xr >= xind && ...
                   yb <= yind && yt >= yind)
                    INTER_FLAG = 1;
                    break;
                end
            end
            if INTER_FLAG ~= 1 || system.emib_via == 1
                system.pkg.type(yind, xind) = type;
                [~, xind] = min(abs(x - chip(i).Xmesh));
                [~, yind] = min(abs(y - chip(i).Ymesh));
                chip(i).type(yind, xind) = type;
                if system.emib_via == 1 && INTER_FLAG == 1
                    chip(i).ubump.R_map(yind, xind) = chip(i).ubump.R_map(yind, xind) + system.TSV.R;
                    chip(i).ubump.L_map(yind, xind) = chip(i).ubump.L_map(yind, xind) + system.TSV.L;
                end
            %%%%including bridge ground%%%%%%%%%%%%%%%%
            elseif (system.bridge_ground == 1 && INTER_FLAG == 1 && type == 2)|| (system.bridge_power == 1 && INTER_FLAG == 1)
                system.pkg.type(yind, xind) = type;
                [~, xind] = min(abs(x - chip(i).Xmesh));
                [~, yind] = min(abs(y - chip(i).Ymesh));
                chip(i).type(yind, xind) = type;
                chip(i).ubump.R_map(yind, xind) = chip(i).c4.R;
                chip(i).ubump.L_map(yind, xind) = chip(i).c4.L;
            end
        end

        fprintf('Chip #%d actually has %d power bumps\n', i, sum(sum(double(chip(i).type == system.type.P))));
        fprintf('Chip #%d actually has %d ground bumps\n', i, sum(sum(double(chip(i).type == system.type.G))));  

        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%5
        % Adding C4 bump map to chip
        for j = 1:chip(i).c4.P + chip(i).c4.G
            x = chip(i).c4.loc(j,1);
            y = chip(i).c4.loc(j,2);
            type = chip(i).c4.loc(j,3);
            [~, xind] = min(abs(x + chip(i).xl - system.pkg.Xmesh));
            [~, yind] = min(abs(y + chip(i).yb - system.pkg.Ymesh));
            INTER_FLAG = 0;
            for ii = 1 : system.Nbridge 
                xl = system.interbox(ii,1);
                xr = system.interbox(ii,2);
                yb = system.interbox(ii,3);
                yt = system.interbox(ii,4);
                if (xl <= xind && xr >= xind && ...
                   yb <= yind && yt >= yind)
                    INTER_FLAG = 1;
                    break;
                end
            end
            if INTER_FLAG ~= 1 || system.emib_via == 1
                %system.pkg.type(yind, xind) = type;
                [~, xind] = min(abs(x - chip(i).Xmesh));
                [~, yind] = min(abs(y - chip(i).Ymesh));
                chip(i).typec4(yind, xind) = type;
            %%%%including bridge ground%%%%%%%%%%%%%%%%
            elseif (system.bridge_ground == 1 && INTER_FLAG == 1 && type == 2)|| (system.bridge_power == 1 && INTER_FLAG == 1)
                system.pkg.type(yind, xind) = type;
                [~, xind] = min(abs(x - chip(i).Xmesh));
                [~, yind] = min(abs(y - chip(i).Ymesh));
                chip(i).type(yind, xind) = type;
                chip(i).c4.R_map(yind, xind) = chip(i).c4.R;
                chip(i).c4.L_map(yind, xind) = chip(i).c4.L;
            end
        end
        fprintf('Chip #%d actually has %d power c4 bumps\n', i, sum(sum(double(chip(i).typec4 == system.type.P))));
        fprintf('Chip #%d actually has %d ground c4 bumps\n', i, sum(sum(double(chip(i).typec4 == system.type.G))));   

        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%5
        for j = 1:chip(i).TSV.P + chip(i).TSV.G
            x = chip(i).TSV.loc(j,1);
            y = chip(i).TSV.loc(j,2);
            type = chip(i).TSV.loc(j,3);
            [~, xind] = min(abs(x + chip(i).xl - system.pkg.Xmesh));
            [~, yind] = min(abs(y + chip(i).yb - system.pkg.Ymesh));
            INTER_FLAG = 0;
            for ii = 1 : system.Nbridge 
                xl = system.interbox(ii,1);
                xr = system.interbox(ii,2);
                yb = system.interbox(ii,3);
                yt = system.interbox(ii,4);
                if (xl <= xind && xr >= xind && ...
                   yb <= yind && yt >= yind)
                    INTER_FLAG = 1;
                    break;
                end
            end
            if INTER_FLAG ~= 1 || system.emib_via == 1
                system.pkg.type(yind, xind) = type;
                [~, xind] = min(abs(x - chip(i).Xmesh));
                [~, yind] = min(abs(y - chip(i).Ymesh));
                chip(i).typeTSV(yind, xind) = type;
                if system.emib_via == 1 && INTER_FLAG == 1
                    chip(i).TSV.R_map(yind, xind) = chip(i).TSV.R_map(yind, xind) + system.TSV.R;
                    chip(i).TSV.L_map(yind, xind) = chip(i).TSV.L_map(yind, xind) + system.TSV.L;
                end
            %%%%including bridge ground%%%%%%%%%%%%%%%%
            elseif (system.bridge_ground == 1 && INTER_FLAG == 1 && type == 2)|| (system.bridge_power == 1 && INTER_FLAG == 1)
                system.pkg.type(yind, xind) = type;
                [~, xind] = min(abs(x - chip(i).Xmesh));
                [~, yind] = min(abs(y - chip(i).Ymesh));
                chip(i).typeTSV(yind, xind) = type;
                chip(i).TSV.R_map(yind, xind) = chip(i).c4.R;
                chip(i).TSV.L_map(yind, xind) = chip(i).c4.L;
            end
        end
        fprintf('Chip #%d actually has %d power bumps\n', i, sum(sum(double(chip(i).typeTSV == system.type.P))));
        fprintf('Chip #%d actually has %d ground bumps\n', i, sum(sum(double(chip(i).typeTSV == system.type.G))));  


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%     
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % c4 map
        if drawM
            const =  chip(i).Nx * chip(i).Ny;
            [X, Y] = meshgrid(chip(i).Xmesh, chip(i).Ymesh);


            color = ['r', 'b'];
            marker = ['o', 'o'];        

            drawdata = [reshape(X', const, 1), reshape(Y', const, 1), reshape(chip(i).typec4', const, 1)];
            m = 1;
            for type = [system.type.P system.type.G]
                figure(5)
                Id = floor(drawdata(:,3)) == type;
                Drawdata = drawdata(Id,:);
                plot(Drawdata(:,1)', Drawdata(:,2)', [color(m), marker(m)], 'MarkerSize', 5); 
                title('c4 map')
                axis equal;
                hold on;
                m = m + 1;
            end  
     
            color = ['r', 'b'];
            marker = ['*', '*'];        
            drawdata = [reshape(X', const, 1), reshape(Y', const, 1), reshape(chip(i).typeTSV', const, 1)];
            m = 1;
            for type = [system.type.P system.type.G]
                figure(6)
                Id = floor(drawdata(:,3)) == type;
                Drawdata = drawdata(Id,:);
                plot(Drawdata(:,1)', Drawdata(:,2)', [color(m), marker(m)], 'MarkerSize', 5); 
                title('TSV  map')
                axis equal;
                hold on;
                m = m + 1;
            end   
            color = ['r', 'b'];
            marker = ['o', 'o'];   

            drawdata = [reshape(X', const, 1), reshape(Y', const, 1), reshape(chip(i).type', const, 1)];
            m = 1;
            for type = [system.type.P system.type.G]
                figure(7)
                Id = floor(drawdata(:,3)) == type;
                Drawdata = drawdata(Id,:);
                plot(Drawdata(:,1)', Drawdata(:,2)', [color(m), marker(m)], 'MarkerSize', 5); 
                title('ubump map')
                axis equal;
                hold on;
                m = m + 1;
            end     


            %% mixed 1)

            color = ['r', 'b'];
            marker = ['*', '*'];        
            drawdata = [reshape(X', const, 1), reshape(Y', const, 1), reshape(chip(i).typeTSV', const, 1)];
            m = 1;
            for type = [system.type.P system.type.G]
                figure(8)
                Id = floor(drawdata(:,3)) == type;
                Drawdata = drawdata(Id,:);
                plot(Drawdata(:,1)', Drawdata(:,2)', [color(m), marker(m)], 'MarkerSize', 5); 
                title('ubump+TSV  map')
                axis equal;
                hold on;
                m = m + 1;
            end   
            color = ['r', 'b'];
            marker = ['o', 'o'];   

            drawdata = [reshape(X', const, 1), reshape(Y', const, 1), reshape(chip(i).type', const, 1)];
            m = 1;
            for type = [system.type.P system.type.G]

                Id = floor(drawdata(:,3)) == type;
                Drawdata = drawdata(Id,:);
                plot(Drawdata(:,1)', Drawdata(:,2)', [color(m), marker(m)], 'MarkerSize', 5); 

                axis equal;
                hold on;
                m = m + 1;
            end       


            %% mixed 2)

            color = ['r', 'b'];
            marker = ['*', '*'];        
            drawdata = [reshape(X', const, 1), reshape(Y', const, 1), reshape(chip(i).typeTSV', const, 1)];
            m = 1;
            for type = [system.type.P system.type.G]
                figure(9)
                Id = floor(drawdata(:,3)) == type;
                Drawdata = drawdata(Id,:);
                plot(Drawdata(:,1)', Drawdata(:,2)', [color(m), marker(m)], 'MarkerSize', 5); 
                title('c4+TSV  map')
                axis equal;
                hold on;
                m = m + 1;
            end   
            color = ['r', 'b'];
            marker = ['o', 'o'];   

            drawdata = [reshape(X', const, 1), reshape(Y', const, 1), reshape(chip(i).typec4', const, 1)];
            m = 1;
            for type = [system.type.P system.type.G]

                Id = floor(drawdata(:,3)) == type;
                Drawdata = drawdata(Id,:);
                plot(Drawdata(:,1)', Drawdata(:,2)', [color(m), marker(m)], 'MarkerSize', 5); 

                axis equal;
                hold on;
                m = m + 1;
            end                

            %% mixed 3)

            color = ['r', 'b'];
            marker = ['*', '*'];        
            drawdata = [reshape(X', const, 1), reshape(Y', const, 1), reshape(chip(i).type', const, 1)];
            m = 1;
            for type = [system.type.P system.type.G]
                figure(10)
                Id = floor(drawdata(:,3)) == type;
                Drawdata = drawdata(Id,:);
                plot(Drawdata(:,1)', Drawdata(:,2)', [color(m), marker(m)], 'MarkerSize', 5); 
                title('c4+ubump  map')
                axis equal;
                hold on;
                m = m + 1;
            end   
            color = ['r', 'b'];
            marker = ['o', 'o'];   

            drawdata = [reshape(X', const, 1), reshape(Y', const, 1), reshape(chip(i).typec4', const, 1)];
            m = 1;
            for type = [system.type.P system.type.G]

                Id = floor(drawdata(:,3)) == type;
                Drawdata = drawdata(Id,:);
                plot(Drawdata(:,1)', Drawdata(:,2)', [color(m), marker(m)], 'MarkerSize', 5); 

                axis equal;
                hold on;
                m = m + 1;
            end 
        end

    end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%     
    
    %find the package domain separation
    if system.chip.N > 1
        [indl, ~] = chip2pkgId(chip(1).Xmesh(end), chip(1).Ymesh(1), chip(1), system.pkg);
        [indr, ~] = chip2pkgId(chip(2).Xmesh(1), chip(2).Ymesh(1), chip(2), system.pkg);
        if mod(indr-indl, 2) == 0
            sep = [(indr + indl)/2-1, (indr + indl)/2];
        else
            sep = [indl + (indr - indl -1)/2, indr - (indr - indl -1)/2];
        end
    end
    
    %% need a better function to do domain separation
    system.pkg.domain = ones(system.pkg.Ny, system.pkg.Nx);
    if system.chip.N > 1
        system.pkg.domain(1:system.pkg.Ny, 1:sep(1)) = 1;
        system.pkg.domain(1:system.pkg.Ny, sep(2):system.pkg.Nx) = 2;
    end
    
    %% calculate decaps per area
    xl = box(1); xr = box(2);
    yb = box(3); yt = box(4);
    area_pkg = system.pkg.Xsize * system.pkg.Ysize;    
    area_decap = area_pkg - (system.pkg.Xmesh(xr) - system.pkg.Xmesh(xl)) ...
                 *(system.pkg.Ymesh(yt) - system.pkg.Ymesh(yb));
    system.pkg.decap = [system.pkg.decap(1)/area_decap system.pkg.decap(2)*area_decap ...
                        system.pkg.decap(3)*area_decap];
    system.pkg.IsCap(yb : yt, xl : xr) = 0;
    
    %% mark the IOs
    for i = 1 : system.BGA.P + system.BGA.G
        x = system.BGA.loc(i,1);
        y = system.BGA.loc(i,2);
        type = system.BGA.loc(i,3);
        [~, xind] = min(abs(x - system.pkg.Xmesh));
        [~, yind] = min(abs(y - system.pkg.Ymesh));
        % type*10 will make the left digit to record BGA information
        % the right digit for microbump information
        system.pkg.type(yind, xind) = system.pkg.type(yind, xind) + type*10;
    end
    const = system.pkg.Ny * system.pkg.Nx;
    if drawM
        %%%% Package BGA/ubump map+ grid
        [X, Y] = meshgrid(system.pkg.Xmesh, system.pkg.Ymesh);
        drawdata = [reshape(X', const, 1), reshape(Y', const, 1), reshape(system.pkg.type', const, 1)];
        color = ['k', 'r', 'b'];
        marker = ['.', 'o', 'o'];
        i = 1;
        for type = [0 system.type.P system.type.G]
            figure(1)
            Id = floor(drawdata(:,3)/10) == type;
            Drawdata = drawdata(Id,:);
            plot(Drawdata(:,1)', Drawdata(:,2)', [color(i), marker(i)], 'MarkerSize', 5); 
            title('BGA+grid map (Package)')
            axis equal;
            hold on;
            figure(2)
            %% remainder after divison
            Id = mod(drawdata(:,3),10) == type;
            Drawdata = drawdata(Id,:);
            plot(Drawdata(:,1)', Drawdata(:,2)', [color(i), marker(i)], 'MarkerSize', 5); 
            title('ubump+grid map (Package)')
            axis equal;
            hold on;
            i = i + 1;
        end
        color = ['r', 'b'];
        marker = ['o', 'o'];        
        i = 1;
        for type = [system.type.P system.type.G]
            figure(3)
            Id = floor(drawdata(:,3)/10) == type;
            Drawdata = drawdata(Id,:);
            plot(Drawdata(:,1)', Drawdata(:,2)', [color(i), marker(i)], 'MarkerSize', 5); 
            axis equal;
            hold on;
            figure(4)
            Id = mod(drawdata(:,3),10) == type;
            Drawdata = drawdata(Id,:);
            plot(Drawdata(:,1)'*100, Drawdata(:,2)'*100, [color(i), marker(i)], 'MarkerSize', 5); 
            axis equal;
            hold on;
            i = i + 1;
        end          

        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%




    end
    %%%%%%%%%%%%%%% ??????????????????????? %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    [accu_map, blk_name] = chip_array(chip, system.chip.N);
    accu_map = [accu_map; system.connect];
    for i=1:size(system.connect, 1)
        blk_name = [blk_name; cellstr('bridge')];
    end    
    DrawSteady(4, system.pkg.Xmesh, system.pkg.Ymesh, [], accu_map, blk_name, system); 


    
    fprintf('Mark microbumps and BGAs, Using %.2f seconds\n', toc);
end