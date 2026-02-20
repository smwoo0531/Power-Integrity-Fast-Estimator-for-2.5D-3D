function system = BGAGen(system)
%Generate BGA positions and types
    Nx = floor(system.pkg.Xsize/(system.BGA.px/2)) + 1;
    Ny = floor(system.pkg.Ysize/(system.BGA.py/2)) + 1;
    Nmax = Nx * Ny;
    system.BGA.loc = zeros(Nmax, 3);
    pointer = 1;      
    if system.BGA.staggered == 1
        for type = [system.type.P system.type.G]
        if system.BGA.vdd_first == 1 
           
            if type == system.type.P
                xl = 0 ;
                yb = 0;
            else
                xl = system.BGA.px/2;
                yb = system.BGA.py/2;
            end
        else
            if type == system.type.P
                xl = system.BGA.px/2;
                yb = system.BGA.py/2;

             else
                xl = 0 ;
                yb = 0;
            end
        end
        x = xl;
        y = yb;

        while(y<system.pkg.Ysize + 1e-6)
            system.BGA.loc(pointer, :) = [x y type];
              pointer = pointer + 1;
            x = x + system.BGA.px;
            if x > system.pkg.Xsize + 1e-6
                if system.BGA.vdd_first == 1 
                    if type == system.type.P
                        x= 0;
                    else 
                         x = system.BGA.px/2;
                    end
                    y = y + system.BGA.py;
                else
                    if type == system.type.P
                          x = system.BGA.px/2;     
                    else 
                          x= 0;
                    end
                    y = y + system.BGA.py;                    
                end
            end
            end
        end
        
    else
        
        for type = [system.type.P system.type.G]
            if system.BGA.vdd_first == 1 
                if type == system.type.P
                     xl =0 ;
                else
                    xl = system.BGA.px/2;
                end
            else 
                if type == system.type.P
                    xl = system.BGA.px/2;

                else
                    xl =0 ;
            end
        end
        yb = 0;
        x = xl;
        y = yb;
        while(y<system.pkg.Ysize + 1e-6)
            system.BGA.loc(pointer, :) = [x y type];
            pointer = pointer + 1;
            x = x + system.BGA.px;
            if x > system.pkg.Xsize + 1e-6
                if system.BGA.vdd_first == 1 
                    if type == system.type.P
                      x= 0;
                    else 
                        x = system.BGA.px/2;
                    end

                    y = y + system.BGA.py;
                    else
                        if type == system.type.P
                            x = system.BGA.px/2;

                        else 
                            x= 0;
                        end
                        y = y + system.BGA.py;
                    end
                end
            end
        end
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    end



    system.BGA.loc = system.BGA.loc(1:pointer-1, :);
    system.BGA.P = sum(double(system.BGA.loc(:,3) == system.type.P));
    system.BGA.G = sum(double(system.BGA.loc(:,3) == system.type.G));
    fprintf('Package has %d power bumps\n', system.BGA.P);
    fprintf('Package has %d ground bumps\n', system.BGA.G);    
end

