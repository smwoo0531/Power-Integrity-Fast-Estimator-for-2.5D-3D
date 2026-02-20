function power_loss(system, var, Y, x)
    total = x'*Y*x;
    fprintf('total power loss: %.2f\n', total);
end