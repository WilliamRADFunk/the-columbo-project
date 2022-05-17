$suspects = @(
    [PSCustomObject]@{
        Name="msportalfx-mock";
        Url="https://github.com/WilliamRADFunk/msportalfx-mock.git";
    }
);

foreach($suspect in $suspects) {
    git clone $($suspect.Url);
}