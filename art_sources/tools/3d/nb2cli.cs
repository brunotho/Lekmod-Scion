// Command line front end for Nexus Buddy 2 (calls its own functions without showing the window).
//   nb2cli exportnb2 <in.gr2>                         -> NB2 export of every model (Nexus Buddy writes it next to the input)
//   nb2cli overwrite <in.gr2> <meshes.br2> <out.gr2>  -> replaces the meshes of model 0 with the BR2 meshes and saves
// Build (x86, next to NexusBuddy2.exe):
//   csc /platform:x86 /out:nb2cli.exe /r:NexusBuddy2.exe /r:Firaxis.Framework.dll /r:Firaxis.Framework.Granny.dll nb2cli.cs
using System;
using System.IO;
using System.Reflection;
using System.Windows.Forms;

static class Nb2Cli
{
    [STAThread]
    static int Main(string[] a)
    {
        try
        {
            var asm = typeof(NexusBuddy.NexusBuddyApplicationForm).Assembly;
            var bf = BindingFlags.Instance | BindingFlags.Static | BindingFlags.Public | BindingFlags.NonPublic;
            var form = new NexusBuddy.NexusBuddyApplicationForm();
            var formType = form.GetType();
            string inPath = Path.GetFullPath(a[1]);
            object file = formType.GetMethod("openFileAction", bf).Invoke(form, new object[] { inPath });
            formType.GetField("loadedFile", bf).SetValue(null, file);
            Console.WriteLine("opened " + inPath);
            if (a[0] == "exportnb2")
            {
                asm.GetType("NexusBuddy.FileOps.NB2Exporter").GetMethod("exportAllModelsToNB2", bf).Invoke(null, new object[] { file });
                Console.WriteLine("exported NB2");
            }
            else if (a[0] == "overwrite")
            {
                var gc = Firaxis.Framework.Context.Get<Firaxis.Framework.Granny.GrannyContext>();
                asm.GetType("NexusBuddy.FileOps.BR2Importer").GetMethod("overwriteMeshes", bf)
                   .Invoke(null, new object[] { file, Path.GetFullPath(a[2]), gc, 0 });
                Console.WriteLine("meshes overwritten");
                formType.GetMethod("saveAsAction", bf).Invoke(form, new object[] { file, Path.GetFullPath(a[3]), false });
                Console.WriteLine("saved " + Path.GetFullPath(a[3]));
            }
            return 0;
        }
        catch (Exception e)
        {
            for (var x = e; x != null; x = x.InnerException) Console.WriteLine("EXC " + x.GetType().Name + ": " + x.Message + "\n" + x.StackTrace);
            return 1;
        }
    }
}
