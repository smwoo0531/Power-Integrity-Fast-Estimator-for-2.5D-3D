function chip_ = c4Gen(system, chip)
%Generate microbump positions and types
    for i = 1:system.chip.N
        Nx = floor(chip(i).Xsize/(chip(i).c4.px/2)) + 1;
        Ny = floor(chip(i).Ysize/(chip(i).c4.py/2)) + 1;
        Nmax = Nx * Ny;
        chip(i).c4.loc = zeros(Nmax, 3);
        pbump = 1;      


        if chip(i).c4.staggered == 1
            for type = [system.type.P system.type.G]
                if chip(i).c4.vdd_first == 1 


                    if type == system.type.P
                       xl = 0 ;
                       yb = 0;
                    else
                        xl = chip(i).c4.px/2;
                        yb = chip(i).c4.py/2;
                    end
                else
                    if type == system.type.P
                        xl = chip(i).c4.px/2;
                        yb = chip(i).c4.py/2;                        

                    else
                       xl = 0 ;
                       yb = 0;
                    end
                end
    
                x = xl;
                y = yb;
    
                while(y<chip(i).Ysize + 1e-6)
                    chip(i).c4.loc(pbump, :) = [x y type];
                    pbump = pbump + 1;
                    x = x + chip(i).c4.px;
    
                    if x > chip(i).Xsize + 1e-6


                        if chip(i).c4.vdd_first == 1                     
                            if type == system.type.P
                                x= 0;
                            else 
                                x = chip(i).c4.px/2;
        
                            end
                        else 
                            if type == system.type.P
                                x = chip(i).c4.px/2;

                            else 
                                x= 0;
        
                            end           
                        end
                         y = y + chip(i).c4.py;
    
                    end
                end
            end
        else
            for type = [system.type.P system.type.G]
                if chip(i).c4.vdd_first == 1 
                    if type == system.type.P
                        xl = 0;
                    else
                        xl = chip(i).c4.px/2;
                    end
                    % yb = chip(i).c4.py/2;
                    yb = 0;
                    x = xl;
                    y = yb;
                    while(y<chip(i).Ysize + 1e-6)
                        chip(i).c4.loc(pbump, :) = [x y type];
                        pbump = pbump + 1;
                        x = x + chip(i).c4.px;
                        if x > chip(i).Xsize + 1e-6
                            if type == system.type.P
                                x = 0;
                            else
                                x = chip(i).c4.px/2;
                            end
                            y = y + chip(i).c4.py;
                        end
                    end      
                else
                    if type == system.type.P
                        xl = chip(i).c4.px/2;
                    else
                        xl = 0;
                    end
                    yb = 0;
                    x = xl;
                    y = yb;
                    while(y<chip(i).Ysize + 1e-6)
                        chip(i).c4.loc(pbump, :) = [x y type];
                        pbump = pbump + 1;
                        x = x + chip(i).c4.px;
                        if x > chip(i).Xsize + 1e-6
                            if type == system.type.P
                                x = chip(i).c4.px/2;
                            else
                                x = 0;
                            end
                            y = y + chip(i).c4.py;
                        end
                    end                    
                end

            end
        end
        chip(i).c4.loc = chip(i).c4.loc(1:pbump-1, :);
        chip(i).c4.P = sum(double(chip(i).c4.loc(:,3) == system.type.P));
        chip(i).c4.G = sum(double(chip(i).c4.loc(:,3) == system.type.G));
        fprintf('Chip #%d could have %d power c4\n', i, chip(i).c4.P);
        fprintf('Chip #%d could have %d ground c4\n', i, chip(i).c4.G);
    end
    chip_ = chip;
end

