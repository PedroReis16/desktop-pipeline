using Desktop.Export;

var builder = Host.CreateApplicationBuilder(args);

// Permite que o mesmo binario rode como Servico do Windows (SCM)...
builder.Services.AddWindowsService(options =>
{
    options.ServiceName = "Desktop Export";
});

// ...ou como unidade do systemd no Linux. Ambos sao no-op quando executados
// como aplicacao de console comum (ex.: durante o desenvolvimento).
builder.Services.AddSystemd();

builder.Services.AddHostedService<Worker>();

var host = builder.Build();
host.Run();
