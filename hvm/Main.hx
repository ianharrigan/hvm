package hvm;

class Main {
    static function main() {
        //try {
            HVM.init();
            HVM.log("");
            HVM.log("Haxe Version Manager");
            HVM.log("");
            //HVM.log("Compilers dir: " + HVM.compilersDir);
            
            var args = Sys.args();
            var workingDir = args.pop();
            if (args == null || args.length == 0) {
                help(args);
            } else {
                var cmd = args.shift();
                switch (cmd) {
                    case "set":
                        set(args);
                    case "restore":
                        restore(args);
                    case "list":
                        list(args);
                    case "help":
                        help(args);
                    default:
                        HVM.log("");
                        HVM.log("Unknown command: " + cmd);
                        HVM.log("");
                        help([]);
                }
            }
            /*
        } catch (e:Dynamic) {
            HVM.log(e);
        }
        */
    }
    
    static function set(args:Array<String>) {
        switch (args[0]) {
            case "latest":
                HVM.log("");
                HVM.log("Not yet implmented!");
            case "official":
                if (args[1] == null) {
                    HVM.log("");
                    HVM.log("No version specified");
                    HVM.log("");
                    list(["official"]);
                    return;
                }
                var official = HVM.resolveOfficial(args[1]);
                if (official != null) {
                    HVM.log("Official found " + args[1] + " => " + official);
                    HVM.installOfficial(official);
                } else {
                    HVM.log("");
                    HVM.log("Official '" + args[1] + "' not found");
                    HVM.log("");
                    list(["official"]);
                }
                HVM.log("");
            case "nightly":
                if (args[1] == null) {
                    HVM.log("");
                    HVM.log("No version specified");
                    HVM.log("");
                    list(["nightly"]);
                    return;
                }
                var nightly = HVM.resolveNightly(args[1]);
                if (nightly != null) {
                    HVM.log("Nightly found " + args[1] + " => " + nightly);
                    HVM.installNightly(nightly);
                } else {
                    HVM.log("");
                    HVM.log("Nightly '" + args[1] + "' not found");
                    HVM.log("");
                    list(["nightly"]);
                }
                HVM.log("");
            default:
                HVM.log("");
                HVM.log("Unknown 'set' argument: " + args[0]);
        }
    }
    
    static function restore(args:Array<String>) {
        HVM.restoreBackup();
        HVM.log("");
    }
    
    static function list(args:Array<String>) {
        switch (args[0]) {
            case "local":
                var list = HVM.listLocal();
                HVM.log("Compilers located in '" + HVM.compilersDir + "':");
                HVM.log("");
                printList(list);
            case "official":
                var list = HVM.listOfficial();
                HVM.log("Official releases located on GitHub:");
                HVM.log("");
                printList(list);
            case "nightly":
                var max = 60;
                var list = HVM.listNightly(max);
                HVM.log("Most recent " + max + " nightly releases found on build.haxe.org:");
                HVM.log("");
                printList(list);
            default:
                HVM.log("Unknown 'list' argument: " + args[0]);
        }
        
        HVM.log("");
        HVM.log("");
    }
    
    static function help(args:Array<String>) {
        HVM.log("    set - downloads and sets the haxe version, examples:");
        HVM.log("        haxelib run hvm set official 4.1.4");
        HVM.log("        haxelib run hvm set nightly 97877fd");
        HVM.log("        haxelib run hvm set nightly latest");
        HVM.log("        haxelib run hvm set latest");
        HVM.log("");
        HVM.log("    restore - restores backup version of haxe, examples:");
        HVM.log("        haxelib run hvm restore");
        HVM.log("");
        HVM.log("    list - list of haxe compilers, examples:");
        HVM.log("        haxelib run hvm list local");
        HVM.log("        haxelib run hvm list official");
        HVM.log("        haxelib run hvm list nightly");
        HVM.log("");
    }
    
    private static var MAX_WIDTH:Int = 80;
    static function printList(list:Array<String>) {
        var biggest = -1;
        for (item in list) {
            if (item.length > biggest) {
                biggest = item.length;
            }
        }
        var columns = Math.floor(MAX_WIDTH / (biggest + 5));
        var n = 0;
        for (i in 0...list.length) {
            var padded = StringTools.rpad(list[i], " ", biggest + 5);
            if (n == 0) {
                Sys.print("        ");
            }
            Sys.print(padded);
            n++;
            if (n >= columns) {
                Sys.print("\n");
                n = 0;
            }
        }
    }
}