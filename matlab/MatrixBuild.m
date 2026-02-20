function Y = MatrixBuild(A, D, var)
%UNTITLED2 Summary of this function goes here
%   Detailed explanation goes here
    A = -(A + A');
    Dsum = -sum(A(1:var, :));
    Dsum = sparse(1:var, 1:var, Dsum, var, var);
    Y = A + D + Dsum;
end

