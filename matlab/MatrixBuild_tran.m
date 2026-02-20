function Y = MatrixBuild_tran(Aall, var)
%UNTITLED2 Summary of this function goes here
%   Detailed explanation goes here
    A = Aall(1:var, 1:var);
    [i,j,s] = find(A);
    [m,n] = size(Aall);
    Aminus = sparse(i,j,-s,m,n);
    A = -(A + A');
    Dsum = -sum(A(1:var, :));
    Dsum = sparse(1:var, 1:var, Dsum, var, var);
    A = A + Dsum;
    [i,j,s] = find(A);
    Aplus = sparse(i,j,s,m,n);
    Y = Aall + Aminus + Aplus;
end

