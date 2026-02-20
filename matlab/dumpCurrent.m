function current  = dumpCurrent(system, chip, var, drawP)

          
    tic;
    current = zeros(var, 1);
    drawP_pkg = ones(system.pkg.Ny, system.pkg.Nx)*NaN;
    for ii = 1:system.chip.N
        die_num = chip(ii).N;
        drawP_die = zeros(chip(ii).Ny, chip(ii).Nx, chip(ii).N);

        gridNx_chip = chip(ii).Nx;
        gridNy_chip = chip(ii).Ny;
        chip_xmesh = chip(ii).Xmesh;
        chip_ymesh = chip(ii).Ymesh;


        %% power map debug
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        for DIE = 1:1:die_num
            %this is for assigning the background power excitation
            
            background = 0;
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

        
            %calculate whether need to assign background power
            if End-start < 0 % Need to change - the 2 dies are not the same size
                % force the 2nd die to be half the chip size of die1

                %%??? change
                %if DIE ~= die_num
                %    background = chip(ii).power(DIE)/((chip(ii).Xsize*chip(ii).Ysize)*system.Vdd.val);
                %else
                %   background = chip(ii).power(DIE)/(((chip(ii).Xsize/2)*(chip(ii).Ysize/2))*system.Vdd.val);
                %end
                background = chip(ii).power(DIE)/((chip(ii).Xsize*chip(ii).Ysize)*system.Vdd.val);
                
            else

                if abs(chip(ii).power(DIE) - sum(chip(ii).map(start:End, 5))) > 1e-8
                    power_back = chip(ii).power(DIE) - sum(chip(ii).map(start:End, 5));
                    tmp = chip(ii).Xsize*chip(ii).Ysize - chip(ii).map(start:End, 3)'*chip(ii).map(start:End, 4);
                    if tmp <= 10e-12
                        area_back = chip(ii).Xsize*chip(ii).Ysize;
                    else
                        area_back = tmp;
                    end
                    background = power_back / (area_back*system.Vdd.val);
                end
            end
            if system.debug_power == 1
                    fprintf('****debug: DIE: %d , start: %d , End: %d  background: %d\n',  DIE, start, End, background)
            end  


            idOffset = 0;
            for jj = 1:ii-1
                idOffset = idOffset + chip(jj).numV;
            end



  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
             %%% flat power
            if background > 1e-8
                for i = 1:1:gridNx_chip
                    for j=1:1:gridNy_chip
                        id = i+(j-1)*gridNx_chip+idOffset+(DIE-1)*2*chip(ii).Nx*chip(ii).Ny;
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

                        % we are at die2
                        if DIE == die_num
                            % Tiermap tells us location of chiplet in reference to chip1
                            if system.version ~= 0
                                if system.RDL==0
                                    tiermap = findmap(system,chip, chip(1).blk_num(2));
                                else
                                    tiermap = findmap(system,chip, chip(1).blk_num(3));
                                end
                            end

                            %% add for f2f bottom die 0620
                            %if system.structure == 2
                            %    id = id+chip(ii).Nx*chip(ii).Ny;
                            % end
                            if system.structure == 1 && chip.intermetal.usage == 1
                                id = id+chip(ii).Nx*chip(ii).Ny;
                            end
                            
                            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                     
                            gridx = boundary(2) - boundary(1);
                            gridy = boundary(4) - boundary(3);
                            area = gridx*gridy;
                            % Check if we are at the location of the
                            % chiplet
                            if system.version ~= 0
                                if tiermap(i,j) == 1
                                     current(id) = current(id) + background*area;
                                     drawP_die(j,i,DIE) = background;
                                end
                            %%%%%%%%%%%%%%%%%%%%
                            else
                                current(id) = current(id) + background*area;
                                drawP_die(j,i,DIE) = background;
                            end

                            %%%%%%%%%%%%%%%%%%%%%5
                           % end

                        else % we are at die1
                            gridx = boundary(2) - boundary(1);
                            gridy = boundary(4) - boundary(3);
                            area = gridx*gridy;

                            if system.version ~= 0 && DIE==1
                                tiermap = findmap(system,chip, chip(1).blk_num(1));
                                if tiermap(i,j) == 1
                                     current(id) = current(id) + background*area;
                                     drawP_die(j,i,DIE) = background;
                                end
                            else
                                current(id) = current(id) + background*area;
          
                                drawP_die(j,i,DIE) = background;
                            end
                        end
                    end
                end
            end
            

            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            %assign the block power maps


            if End < start
                continue
            else
                density = zeros(1, sum(chip(ii).blk_num(DIE)));
            end
            
            for k=start:1:End
                density(k) = chip(ii).map(k,5)/(chip(ii).map(k,3)*chip(ii).map(k,4)*system.Vdd.val) - background;
                if (density(k) == 0)
                    continue;
                end
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
                        id = i+(j-1)*gridNx_chip+idOffset+(DIE-1)*2*chip(ii).Nx*chip(ii).Ny;

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

                        current(id) = current(id) + density(k)*grid_area;
                        drawP_die(j,i,DIE) = current(id)/area;
                    end
                end
            end
        end   
    


        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

        if drawP == 1
            if DIE == chip(ii).N
                Chip_xl = find(abs(system.pkg.Xmesh-chip(ii).xl)<1e-5);
                Chip_yb = find(abs(system.pkg.Ymesh-chip(ii).yb)<1e-5);
                Chip_xr = find(abs(system.pkg.Xmesh-chip(ii).xl - chip(ii).Xsize)<1e-5);
                Chip_yt = find(abs(system.pkg.Ymesh-chip(ii).yb - chip(ii).Ysize)<1e-5);    
                drawP_pkg(Chip_yb:Chip_yt,Chip_xl:Chip_xr) = drawP_die(:,:,DIE);
            end                
            idOffset = 0;
            for jj = 1:ii-1
                idOffset = idOffset + chip(jj).N;
            end
            for k=1 : chip(ii).N
                if chip(ii).blk_num(k) > 0
                    fprintf("Trying to draw the current map for die 2...")
                    figure(20+idOffset+k);
                    currentmap = drawP_die(:,:,k)*1e-6;
                    % contourf(chip_xmesh*100, chip_ymesh*100,drawP_die(:,:,k)*1e-6, max(chip(ii).blk_num(k))*2,'Linestyle','none');
                    % colormap jet;
                    % axis off;
                    % h=colorbar;
                    % set(get(h,'Title'),'string','A/mm2','FontSize',16)
                    % set(gca,'FontSize',16);
                    % xlabel('x(cm)');
                    % ylabel('y(cm)');set(gca,'FontSize',16);
                else
                    fprintf('Chip #%d, Die #%d has uiform power map, skipped\n', ii, k);
                end
            end
        end     
    end
    
%     if drawP == 1
%         [map, name] = chip_map_stack(chip, system.chip.N);
%         map = [map; system.connect];
%         for i=1:size(system.connect, 1)
%             name = [name; cellstr('bridge')];
%         end    
%         figure(20+system.chip.N+1);
%         contourf(system.pkg.Xmesh*100, system.pkg.Ymesh*100, abs(drawP_pkg)*1e-6, 30, 'Linestyle','none');
% 
%         len = size(map, 1);
%         for i=1:len      
%             xl = map(i,1);
%             width = map(i,3);
%             yb = map(i,2);
%             height = map(i,4);    
%             if strcmp(char(name(i)), 'bridge') == 1
%                 rectangle('Position',[xl yb width height]*100, 'LineWidth', 1.5, 'edgecolor', 'r');
%                 name(i) = cellstr('');
%             else            
%                 rectangle('Position',[xl yb width height]*100, 'LineWidth', 1);
%             end
%             if isempty(char(name(i))) == 0              
%                 text((xl+width/2)*100, (yb+height/2)*100, char(name(i)), 'HorizontalAlignment','center', 'FontSize', 14, 'FontWeight', 'Bold')
%             end
%             hold on;
%         end
%         axis off
%         axis equal;
%         h=colorbar;
%         set(get(h,'Title'),'string','A/mm2','FontSize',16)
%         set(gca,'FontSize',16);
%         xlabel('x(cm)');
%         ylabel('y(cm)');set(gca,'FontSize',16);             
%     end
    
    
    fprintf('Total current: %.2f A\n', sum(current));
    fprintf('Current dumped to vector, using %.2f seconds\n', toc);
end