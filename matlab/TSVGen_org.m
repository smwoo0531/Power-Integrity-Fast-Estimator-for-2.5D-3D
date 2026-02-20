function chip_ = TSVGen(system, chip)
%Generate microbump positions and types
    for i = 1:system.chip.N
        Nx = floor(chip(i).Xsize/(chip(i).TSV.px/2)) + 1;
        Ny = floor(chip(i).Ysize/(chip(i).TSV.py/2)) + 1;
        Nmax = Nx * Ny;
        chip(i).TSV.loc = zeros(Nmax, 3);
        pbump = 1;  

        
        if chip(i).TSV.staggered == 1
            for type = [system.type.P system.type.G]
                if chip(i).TSV.vdd_first == 1 


                    if type == system.type.P
                       xl = 0 +chip(i).TSV.xoffset;
                       yb = 0 +chip(i).TSV.yoffset;
                    else
                        xl = chip(i).TSV.px/2+chip(i).TSV.xoffset;
                        yb = chip(i).TSV.py/2+chip(i).TSV.yoffset;
                    end
                else
                    if type == system.type.P
                        xl = chip(i).TSV.px/2+chip(i).TSV.xoffset;
                        yb = chip(i).TSV.py/2+chip(i).TSV.yoffset;                        

                    else
                       xl = 0 +chip(i).TSV.xoffset;
                       yb = 0 +chip(i).TSV.yoffset;
                    end
                end
    
                x = xl;
                y = yb;
    
                while(y<chip(i).Ysize + 1e-6)
                    chip(i).TSV.loc(pbump, :) = [x y type];
                    pbump = pbump + 1;
                    x = x + chip(i).TSV.px;
    
                    if x > chip(i).Xsize + 1e-6


                        if chip(i).TSV.vdd_first == 1                     
                            if type == system.type.P
                                x= 0+chip(i).TSV.xoffset;
                            else 
                                x = chip(i).TSV.px/2+chip(i).TSV.xoffset;
        
                            end
                        else 
                            if type == system.type.P
                                x = chip(i).TSV.px/2+chip(i).TSV.xoffset;

                            else 
                                x= 0+chip(i).TSV.xoffset;
        
                            end           
                        end
                         y = y + chip(i).TSV.py;
    
                    end
                end
            end
        else
            for type = [system.type.P system.type.G]
                if chip(i).TSV.vdd_first == 1 
                    if type == system.type.P
                        xl = 0+chip(i).TSV.xoffset;
                    else
                        xl = chip(i).TSV.px/2+chip(i).TSV.xoffset;
                    end
                    % yb = chip(i).TSV.py/2;
                    yb = 0+chip(i).TSV.yoffset;
                    x = xl;
                    y = yb;
                    while(y<chip(i).Ysize + 1e-6)
                        chip(i).TSV.loc(pbump, :) = [x y type];
                        pbump = pbump + 1;
                        x = x + chip(i).TSV.px;
                        if x > chip(i).Xsize + 1e-6
                            if type == system.type.P
                                x = 0+chip(i).TSV.xoffset;
                            else
                                x = chip(i).TSV.px/2+chip(i).TSV.xoffset;
                            end
                            y = y + chip(i).TSV.py;
                        end
                    end      
                else
                    if type == system.type.P
                        xl = chip(i).TSV.px/2+chip(i).TSV.xoffset;
                    else
                        xl = 0+chip(i).TSV.xoffset;
                    end
                    yb = 0+chip(i).TSV.yoffset;
                    x = xl;
                    y = yb;
                    while(y<chip(i).Ysize + 1e-6)
                        chip(i).TSV.loc(pbump, :) = [x y type];
                        pbump = pbump + 1;
                        x = x + chip(i).TSV.px;
                        if x > chip(i).Xsize + 1e-6
                            if type == system.type.P
                                x = chip(i).TSV.px/2+chip(i).TSV.xoffset;
                            else
                                x = 0+chip(i).TSV.xoffset;
                            end
                            y = y + chip(i).TSV.py;
                        end
                    end                    
                end

            end
        end

        chip(i).TSV.loc = chip(i).TSV.loc(1:pbump-1, :);
        chip(i).TSV.P = sum(double(chip(i).TSV.loc(:,3) == system.type.P));
        chip(i).TSV.G = sum(double(chip(i).TSV.loc(:,3) == system.type.G));
        fprintf('Chip #%d could have %d power bumps\n', i, chip(i).TSV.P);
        fprintf('Chip #%d could have %d ground bumps\n', i, chip(i).TSV.G);
    end
    chip_ = chip;
end

