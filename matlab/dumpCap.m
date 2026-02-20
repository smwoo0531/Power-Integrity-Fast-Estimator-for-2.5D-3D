function Cap = dumpCap(system, chip, var, DRAW_FLAG)
%assign the decoupling capacitance density to each nose in die, package, and board;
%%assign decap density for dice
    Cap = zeros(var, 3); % to store R, S, L
    itefig = 1;
    tic;
    for ii = 1 : system.chip.N
        die_num = chip(ii).N;
        gridNx_chip = chip(ii).Nx;
        gridNy_chip = chip(ii).Ny;
        chip_xmesh = chip(ii).Xmesh;
        chip_ymesh = chip(ii).Ymesh;
        const = chip(ii).Nx*chip(ii).Ny;
        idoffset = 0;
        for jj = 1:ii-1
            idoffset = idoffset + chip(jj).numV;
        end        
        
        for DIE = 1:1:die_num
            %this is for assigning the background decap density
            background = chip(ii).cap_per(DIE)*chip(ii).c_gate(DIE);
            drawP_die = ones(chip(ii).Ny, chip(ii).Nx)*chip(ii).c_gate(DIE)*chip(ii).cap_per(DIE);

            for i = 1 : gridNx_chip
                for j = 1 : gridNy_chip
                    id = i+(j-1)*gridNx_chip+idoffset+(DIE-1)*2*const;
                    if i == 1
                        boundary(1) = chip_xmesh(i);
                    else
                        boundary(1) = (chip_xmesh(i-1) + chip_xmesh(i))/2;
                    end
                    if i == gridNx_chip
                        boundary(2) = chip_xmesh(i);
                    else
                        boundary(2) = (chip_xmesh(i) + chip_xmesh(i+1))/2;
                    end

                    if j == 1
                        boundary(3) = chip_ymesh(j);
                    else
                        boundary(3) = (chip_ymesh(j-1)+chip_ymesh(j))/2;
                    end
                    if j == gridNy_chip
                        boundary(4) = chip_ymesh(j);
                    else
                        boundary(4) = (chip_ymesh(j)+chip_ymesh(j+1))/2;
                    end
                    grid_area = (boundary(2) - boundary(1))*(boundary(4) - boundary(3));
                    Cap(id) = background * grid_area;
                end
            end            
            
            if DIE == 1
                start = 1;
            else
                start = sum(chip(ii).blk_num(1:DIE-1))+1;
            end
            if DIE == die_num
                End = sum(chip(ii).blk_num(1:DIE));
            else
                End = start + chip(ii).blk_num(DIE)-1;
            end

            %assign the block decap maps
            if End < start
                continue
            else
                cap = zeros(1, sum(chip(ii).blk_num));%zeros(1:End-start);
            end
            
            for k=start:1:End
                cap(k) = chip(ii).map(k,6) - background;
                blkXl = chip(ii).map(k,1);
                blkXr = chip(ii).map(k,1)+chip(ii).map(k,3);
                blkYt = chip(ii).map(k,2);
                blkYb = chip(ii).map(k,2)+chip(ii).map(k,4);
                
                xl = sum(chip_xmesh<blkXl);
                if xl <= 0
                    xl = 1;
                end
                xr = sum(chip_xmesh<blkXr)+1;
                if xr >= gridNx_chip
                    xr = gridNx_chip;
                end
                yb = sum(chip_ymesh<blkYt);
                if yb <= 0
                    yb = 1;
                end
                yt = sum(chip_ymesh<blkYb)+1;
                if yt >= gridNy_chip
                    yt = gridNy_chip;
                end
                boundary_blk = [blkXl blkXr blkYt blkYb];
                
                for i=xl:1:xr
                    for j=yb:1:yt
                        id = i+(j-1)*gridNx_chip+idoffset+(DIE-1)*2*const;
                        if i == 1
                            boundary(1) = chip_xmesh(i);
                        else
                            boundary(1) = (chip_xmesh(i-1)+chip_xmesh(i))/2;
                        end
                        if i == gridNx_chip
                            boundary(2) = chip_xmesh(i);
                        else
                            boundary(2) = (chip_xmesh(i)+chip_xmesh(i+1))/2;
                        end

                        if j == 1
                            boundary(3) = chip_ymesh(j);
                        else
                            boundary(3) = (chip_ymesh(j-1)+chip_ymesh(j))/2;
                        end
                        if j == gridNy_chip
                            boundary(4) = chip_ymesh(j);
                        else
                            boundary(4) = (chip_ymesh(j)+chip_ymesh(j+1))/2;
                        end
                        grid_area = cal_overlap (boundary, boundary_blk);

                        gridx = boundary(2) - boundary(1);
                        gridy = boundary(4) - boundary(3);
                        area = gridx*gridy;

                        Cap(id) = Cap(id) + cap(k)*grid_area;
                        drawP_die(j,i) = Cap(id)/(2*area);
                    end
                end               
            end
            if DRAW_FLAG
                figure(10+itefig);
                itefig = itefig + 1;
                if chip(ii).blk_num(DIE) > 0
                    contourf(chip(ii).Xmesh*100, chip(ii).Ymesh*100, drawP_die*1000, max(chip(ii).blk_num(DIE))*2,'Linestyle','none');
                    h=colorbar;
                    set(get(h,'Title'),'string','nF/mm2','FontSize',16)
                    set(gca,'FontSize',16);
                    xlabel('x(cm)');
                    ylabel('y(cm)');set(gca,'FontSize',16);   
                else
                    fprintf('Chip #%d, Die #%d has uiform decap map, skipped\n', ii, DIE);
                end                        
            end             
        end
    end
    
    const = system.pkg.Nx * system.pkg.Ny;
%    drawP_pkg = zeros(system.pkg.Ny, system.pkg.Nx);
%     for i = 1 : system.pkg.Nx
%         for j = 1 : system.pkg.Ny
%             id = i + (j-1)*system.pkg.Nx + system.chip.numV;
%             if i == 1
%                 boundary(1) = system.pkg.Xmesh(i);
%             else
%                 boundary(1) = (system.pkg.Xmesh(i-1)+system.pkg.Xmesh(i))/2;
%             end
%             if i == system.pkg.Nx
%                 boundary(2) = system.pkg.Xmesh(i);
%             else
%                 boundary(2) = (system.pkg.Xmesh(i)+system.pkg.Xmesh(i+1))/2;
%             end
% 
%             if j == 1
%                 boundary(3) = system.pkg.Ymesh(j);
%             else
%                 boundary(3) = (system.pkg.Ymesh(j-1)+system.pkg.Ymesh(j))/2;
%             end
%             if j == system.pkg.Ny
%                 boundary(4) = system.pkg.Ymesh(j);
%             else
%                 boundary(4) = (system.pkg.Ymesh(j)+system.pkg.Ymesh(j+1))/2;
%             end
%             grid_area = (boundary(2) - boundary(1))*(boundary(4) - boundary(3));
%             Cap(id) = system.pkg.Cdst * grid_area;
%             Cap(id + const) = system.pkg.Cdst * grid_area;
% %            drawP_pkg(j,i) = system.pkg.Cdst; 
%         end
%     end
    
    fprintf('Dumping capacitance out, using %.2f seconds\n', toc);
end