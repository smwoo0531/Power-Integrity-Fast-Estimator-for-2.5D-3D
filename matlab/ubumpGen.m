function chip_ = ubumpGen(system, chip)
%Generate microbump positions and types
    for i = 1:system.chip.N
        Nx = floor(chip(i).Xsize/(chip(i).ubump.px/2)) + 1;
        Ny = floor(chip(i).Ysize/(chip(i).ubump.py/2)) + 1;
        Nmax = Nx * Ny;
        chip(i).ubump.loc = zeros(Nmax, 3);
        pbump = 1;  

        
        if chip(i).ubump.staggered == 1
            for type = [system.type.P system.type.G]
                if chip(i).ubump.vdd_first == 1 


                    if type == system.type.P
                       xl = 0 +chip(i).ubump.xoffset;
                       yb = 0 +chip(i).ubump.yoffset;
                    else
                        xl = chip(i).ubump.px/2+chip(i).ubump.xoffset;
                        yb = chip(i).ubump.py/2+chip(i).ubump.yoffset;
                    end
                else
                    if type == system.type.P
                        xl = chip(i).ubump.px/2+chip(i).ubump.xoffset;
                        yb = chip(i).ubump.py/2+chip(i).ubump.yoffset;                        

                    else
                       xl = 0 +chip(i).ubump.xoffset;
                       yb = 0 +chip(i).ubump.yoffset;
                    end
                end
    
                x = xl;
                y = yb;
    
                while(y<chip(i).Ysize + 1e-6)
                    chip(i).ubump.loc(pbump, :) = [x y type];
                    pbump = pbump + 1;
                    x = x + chip(i).ubump.px;
    
                    if x > chip(i).Xsize + 1e-6


                        if chip(i).ubump.vdd_first == 1                     
                            if type == system.type.P
                                x= 0+chip(i).ubump.xoffset;
                            else 
                                x = chip(i).ubump.px/2+chip(i).ubump.xoffset;
        
                            end
                        else 
                            if type == system.type.P
                                x = chip(i).ubump.px/2+chip(i).ubump.xoffset;

                            else 
                                x= 0+chip(i).ubump.xoffset;
        
                            end           
                        end
                         y = y + chip(i).ubump.py;
    
                    end
                end
            end
        else
            for type = [system.type.P system.type.G]
                if chip(i).ubump.vdd_first == 1 
                    if type == system.type.P
                        xl = 0+chip(i).ubump.xoffset;
                    else
                        xl = chip(i).ubump.px/2+chip(i).ubump.xoffset;
                    end
                    % yb = chip(i).ubump.py/2;
                    yb = 0+chip(i).ubump.yoffset;
                    x = xl;
                    y = yb;
                    while(y<chip(i).Ysize + 1e-6)
                        chip(i).ubump.loc(pbump, :) = [x y type];
                        pbump = pbump + 1;
                        x = x + chip(i).ubump.px;
                        if x > chip(i).Xsize + 1e-6
                            if type == system.type.P
                                x = 0+chip(i).ubump.xoffset;
                            else
                                x = chip(i).ubump.px/2+chip(i).ubump.xoffset;
                            end
                            y = y + chip(i).ubump.py;
                        end
                    end      
                else
                    if type == system.type.P
                        xl = chip(i).ubump.px/2+chip(i).ubump.xoffset;
                    else
                        xl = 0+chip(i).ubump.xoffset;
                    end
                    yb = 0+chip(i).ubump.yoffset;
                    x = xl;
                    y = yb;
                    while(y<chip(i).Ysize + 1e-6)
                        chip(i).ubump.loc(pbump, :) = [x y type];
                        pbump = pbump + 1;
                        x = x + chip(i).ubump.px;
                        if x > chip(i).Xsize + 1e-6
                            if type == system.type.P
                                x = chip(i).ubump.px/2+chip(i).ubump.xoffset;
                            else
                                x = 0+chip(i).ubump.xoffset;
                            end
                            y = y + chip(i).ubump.py;
                        end
                    end                    
                end

            end
        end

        chip(i).ubump.loc = chip(i).ubump.loc(1:pbump-1, :);
        chip(i).ubump.P = sum(double(chip(i).ubump.loc(:,3) == system.type.P));
        chip(i).ubump.G = sum(double(chip(i).ubump.loc(:,3) == system.type.G));
        fprintf('Chip #%d could have %d power bumps\n', i, chip(i).ubump.P);
        fprintf('Chip #%d could have %d ground bumps\n', i, chip(i).ubump.G);
    end
    chip_ = chip;
end

