package hvm;

import haxe.Http;
import haxe.Json;
import haxe.io.Bytes;
import haxe.io.Path;
import sys.FileSystem;
import sys.io.File;
import sys.io.Process;

using StringTools;

class HVM {
    public static var compilersDir:String = null;
    
    public static function init() {
        if (compilersDir == null) {
            compilersDir = Path.normalize(Sys.getCwd() + "/compilers");
        }
        FileSystem.createDirectory(compilersDir);
    }
    
    public static var isLinux(get, null):Bool;
    private static function get_isLinux():Bool {
        return (system == Linux);
    }
    
    public static var isWindows(get, null):Bool;
    private static function get_isWindows():Bool {
        return (system == Windows);
    }
    
    public static var isMac(get, null):Bool;
    private static function get_isMac():Bool {
        return (system == Mac);
    }
    
    public static var currentHaxeVersion(get, null):String;
    private static function get_currentHaxeVersion():String {
        var version = new Process("haxe", ["-version"]).stdout.readAll().toString().trim();
        return version;
    }

    public static var currentNekoVersion(get, null):String;
    private static function get_currentNekoVersion():String {
        var version = new Process("neko", ["-version"]).stdout.readAll().toString().trim();
        return version;
    }
    
    public static var haxeLocation(get, null):String;
    private static function get_haxeLocation():String {
        var version = Path.normalize(new Process("where", ["haxe"]).stdout.readAll().toString().trim());
        return version;
    }

    public static var haxelibTempLocation(get, null):String;
    private static function get_haxelibTempLocation():String {
        return Path.normalize(compilersDir + "/haxelib.temp");
    }
    
    public static function listLocal():Array<String> {
        var list = [];
        var contents = FileSystem.readDirectory(compilersDir);
        for (item in contents) {
            var fullPath = Path.normalize(compilersDir + "/" + item);
            if (FileSystem.isDirectory(fullPath)) {
                var version = StringTools.replace(item, ",", ".");
                list.push(version);
            }
        }
        return list;
    }
    
    public static function listOfficial(?url:String):Array<String> {
        var list = [];
        
        var url:String = url != null ? url : "https://api.github.com/repos/HaxeFoundation/haxe/releases?per_page=100";
        var http = new Http(url);
        http.setHeader("User-Agent", "HVM");
        var httpsFailed:Bool = false;
        var httpStatus:Int = -1;
        http.onStatus = function(status:Int) {
            httpStatus = status;
            if (status == 302) { // follow redirects
                var location = http.responseHeaders.get("location");
                if (location == null) {
                    location = http.responseHeaders.get("Location");
                }
                if (location != null) {
                    listOfficial(location);
                } else {
                    throw "302 (redirect) encountered but no 'location' header found";
                }
            }
        }
        http.onData = function(data:String) {
            if (data != null && data.length > 0) {
                var jsonArray:Array<Dynamic> = Json.parse(data);
                for (item in jsonArray) {
                    list.push(item.name);
                }
            } else {
                throw "    Problem listing official releases: No list data returned from url";
            }
        }
        http.onError = function(error) {
            if (!httpsFailed && url.indexOf("https:") > -1) {
                httpsFailed = true;
                log("Problem listing official releases using http secure: " + error);
                log("Trying again with http insecure...");
                listOfficial( StringTools.replace(url, "https", "http") );
            } else {
                throw "    Problem listing official releases: " + error;
            }
        }
        http.request();
        
        return list;
    }
    
    public static function resolveOfficial(version:String):String {
        var list = listOfficial();
        if (list.indexOf(version) == -1) {
            return null;
        }
        return version;
    }

    public static function listNightly(max:Int = 0xffffff, ?url:String):Array<String> {
        var list = [];
        
        var url:String = url != null ? url : "https://build.haxe.org/builds/haxe/";
        switch (system) {
            case Linux:
                url += "linux64/";
            case Windows:
                url += "windows64/";
            case Mac:
                url += "mac";
            case Unknown:    
                throw "Unknown system!";
        }
        
        var http = new Http(url);
        http.setHeader("User-Agent", "HVM");
        var httpsFailed:Bool = false;
        var httpStatus:Int = -1;
        http.onStatus = function(status:Int) {
            httpStatus = status;
            if (status == 302) { // follow redirects
                var location = http.responseHeaders.get("location");
                if (location == null) {
                    location = http.responseHeaders.get("Location");
                }
                if (location != null) {
                    listNightly(0xffffff, location);
                } else {
                    throw "302 (redirect) encountered but no 'location' header found";
                }
            }
        }
        http.onData = function(data:String) {
            if (data != null && data.length > 0) {
                var n1 = data.indexOf("<pre>");
                var n2 = data.indexOf("</pre>", n1);
                data = data.substring(n1 + 5, n2);
                
                n1 = data.indexOf("<a href=\"");
                var count = 0;
                while (n1 != -1) {
                    n2 = data.indexOf("\"", n1 + 9);
                    var href = data.substring(n1 + 9, n2);
                    var version = StringTools.replace(href, "haxe_", "");
                    version = StringTools.replace(version, ".zip", "");
                    var parts = version.split("_");
                    version = parts.pop();
                    if (version.indexOf("/") == -1) {
                        list.push(version);
                    }
                    n1 = data.indexOf("<a href=\"", n2);
                    count++;
                    if (count >= max) {
                        break;
                    }
                }
            } else {
                throw "    Problem listing official releases: No list data returned from url";
            }
        }
        http.onError = function(error) {
            if (!httpsFailed && url.indexOf("https:") > -1) {
                httpsFailed = true;
                log("Problem listing nightly releases using http secure: " + error);
                log("Trying again with http insecure...");
                listNightly( 0xffffff, StringTools.replace(url, "https", "http") );
            } else {
                throw "    Problem listing nightly releases: " + error;
            }
        }
        http.request();
        
        return list;
    }

    public static function resolveNightly(id:String):String {
        var zip = null;
        var url = "https://build.haxe.org/builds/haxe/";
        switch (system) {
            case Linux:
                url += "linux64/";
            case Windows:
                url += "windows64/";
            case Mac:
                url += "mac";
            case Unknown:    
                throw "Unknown system!";
        }
        
        var http = new Http(url);
        http.setHeader("User-Agent", "HVM");
        http.onStatus = function(status:Int) {
        }
        http.onData = function(data:String) {
            var n1 = data.indexOf("<pre>");
            var n2 = data.indexOf("</pre>", n1);
            data = data.substring(n1 + 5, n2);
            
            n1 = data.indexOf("<a href=\"");
            while (n1 != -1) {
                n2 = data.indexOf("\"", n1 + 9);
                var href = data.substring(n1 + 9, n2);
                if (href.indexOf(id) != -1) {
                    zip = StringTools.replace(href, "haxe_", "");
                    zip = StringTools.replace(zip, ".zip", "");
                    break;
                }
                n1 = data.indexOf("<a href=\"", n2);
            }
        }
        http.onError = function(error) {
            throw "    Problem resolving nightly releases: " + error;
        }
        http.request();
        
        return zip;
    }
    
    public static var system(get, null):System;
    private static function get_system():System {
        if (Sys.systemName().toLowerCase().indexOf("linux") != -1) {
            return Linux;
        } else if (Sys.systemName().toLowerCase().indexOf("windows") != -1) {
            return Windows;
        } else if (Sys.systemName().toLowerCase().indexOf("mac") != -1) {
            return Mac;
        }
        return Unknown;
    }
    
    public static function checkPrerequisites() {
        var location = haxeLocation;
        var pathParts = location.split("/");
        pathParts.pop();
        var haxeStdLocation = Path.normalize(pathParts.join("/") + "/std");
        var haxelibLocation = Path.normalize(pathParts.join("/") + "/haxelib.exe");
        pathParts.pop();
        var nekoLocation = Path.normalize(pathParts.join("/") + "/neko");

        if (FileSystem.exists(location)) {
            try {
                FileSystem.rename(location, location + ".temp");
                FileSystem.rename(location + ".temp", location);
            } catch (e:Dynamic) {
                log("");
                log("ERROR: could not rename haxe, it's likely it was locked by another process.");
                log("");
                log("       If you are using an IDE it's possible it has locked this folder");
                log("       Closing the IDE and re-running the command may fix the issue");
                return false;
            }
        }

        if (FileSystem.exists(haxelibLocation)) {
            try {
                // Remove any old haxelib.exe.temp, if it exists
                if (FileSystem.exists(haxelibTempLocation)) {
                    FileSystem.deleteFile(haxelibTempLocation);
                }
                FileSystem.rename(haxelibLocation, haxelibLocation + ".temp");
                FileSystem.rename(haxelibLocation + ".temp", haxelibLocation);
            } catch (e:Dynamic) {
                log("");
                log("ERROR: could not rename haxelib, it's likely it was locked by another process.");
                log("");
                log("       If you are using an IDE it's possible it has locked this folder");
                log("       Closing the IDE and re-running the command may fix the issue");
                return false;
            }
        }

        if (FileSystem.exists(haxeStdLocation)) {
            try {
                FileSystem.rename(haxeStdLocation, haxeStdLocation + ".temp");
                FileSystem.rename(haxeStdLocation + ".temp", haxeStdLocation);
            } catch (e:Dynamic) {
                log("");
                log("ERROR: could not rename haxe std folder, it's likely it was locked by another process.");
                log("");
                log("       If you are using an IDE it's possible it has locked this folder");
                log("       Closing the IDE and re-running the command may fix the issue");
                return false;
            }
        }

        if (FileSystem.exists(nekoLocation)) {
            try {
                FileSystem.rename(nekoLocation, nekoLocation + ".temp");
                FileSystem.rename(nekoLocation + ".temp", nekoLocation);
            } catch (e:Dynamic) {
                log("");
                log("ERROR: could not rename neko folder, it's likely it was locked by another process.");
                log("");
                log("       If you are using an IDE it's possible it has locked this folder");
                log("       Closing the IDE and re-running the command may fix the issue");
                return false;
            }
        }

        return true;
    }

    public static function restoreBackup() {
        if (!checkPrerequisites()) {
            return;
        }

        var location = haxeLocation;
        var pathParts = location.split("/");
        pathParts.pop();
        var haxeStdLocation = Path.normalize(pathParts.join("/") + "/std");
        var haxelibLocation = Path.normalize(pathParts.join("/") + "/haxelib.exe");
        pathParts.pop();
        var nekoLocation = Path.normalize(pathParts.join("/") + "/neko");

        // Remove any old haxelib.exe.temp, if it exists
        if (FileSystem.exists(haxelibTempLocation)) {
            FileSystem.deleteFile(haxelibTempLocation);
        }
        
        var backupExists:Bool = FileSystem.exists(location + ".backup") || FileSystem.exists(haxelibLocation + ".backup") || FileSystem.exists(haxeStdLocation + ".backup") || FileSystem.exists(nekoLocation + ".backup");
        if (backupExists == false) {
            log("No backup found!");
        } else {
            log("Deleting existing haxe");

            if (FileSystem.exists(haxeStdLocation) && FileSystem.exists(haxeStdLocation + ".backup")) {
                try {
                    FileSystem.deleteDirectory(haxeStdLocation);
                } catch (e) {
                    log("");
                    log("ERROR: could not rename haxe std folder, it's likely it was locked by another process.");
                    log("");
                    log("       If you are using an IDE it's possible it has locked this folder");
                    log("       Closing the IDE and re-running the command may fix the issue");
                    return;
                }
            }

            if (FileSystem.exists(nekoLocation) && FileSystem.exists(nekoLocation + ".backup")) {
                log("Deleting existing neko");
                try {
                    FileSystem.deleteDirectory(nekoLocation);
                } catch (e) {
                    log("");
                    log("ERROR: could not rename neko folder, it's likely it was locked by another process.");
                    log("");
                    log("       If you are using an IDE it's possible it has locked this folder");
                    log("       Closing the IDE and re-running the command may fix the issue");
                    return;
                }
            }

            if (FileSystem.exists(location) && FileSystem.exists(location + ".backup")) {
                FileSystem.deleteFile(location);
            }
            if (FileSystem.exists(haxelibLocation) && FileSystem.exists(haxelibLocation + ".backup")) {
                // Rename currently running haxelib.exe to haxelib.temp and move it to the hvm compilers dir
                FileSystem.rename(haxelibLocation, haxelibTempLocation);
            }
            
            log("Restoring haxe");
            if (FileSystem.exists(haxeStdLocation + ".backup")) {
                try {
                    FileSystem.rename(haxeStdLocation + ".backup", haxeStdLocation);
                } catch (e) {
                    log("");
                    log("ERROR: could not rename haxe std folder, it's likely it was locked by another process.");
                    log("");
                    log("       If you are using an IDE it's possible it has locked this folder");
                    log("       Closing the IDE and re-running the command may fix the issue");
                    return;
                }
            }

            if (FileSystem.exists(nekoLocation + ".backup")) {
                log("Restoring neko");
                try {
                    FileSystem.rename(nekoLocation + ".backup", nekoLocation);
                } catch (e) {
                    log("");
                    log("ERROR: could not rename neko folder, it's likely it was locked by another process.");
                    log("");
                    log("       If you are using an IDE it's possible it has locked this folder");
                    log("       Closing the IDE and re-running the command may fix the issue");
                    return;
                }
            }
            
            if (FileSystem.exists(location + ".backup")) {
                File.copy(location + ".backup", location);
                FileSystem.deleteFile(location + ".backup");
            }
            if (FileSystem.exists(haxelibLocation + ".backup")) {
                File.copy(haxelibLocation + ".backup", haxelibLocation);
                FileSystem.deleteFile(haxelibLocation + ".backup");
            }
        }
        
        log("Current haxe version: " + currentHaxeVersion + " | Current neko version: " + currentNekoVersion);
    }
    
    public static function installOfficial(version:String) {
        if (!checkPrerequisites()) {
            return;
        }

        downloadOfficial(version);

        var newNekoLocation:String = downloadNeko(version);
		
		restoreBackup();
        
        var location = haxeLocation;
        var pathParts = location.split("/");
        pathParts.pop();
        var haxeStdLocation = Path.normalize(pathParts.join("/") + "/std");
        var haxelibLocation = Path.normalize(pathParts.join("/") + "/haxelib.exe");
        pathParts.pop();
        var nekoLocation = Path.normalize(pathParts.join("/") + "/neko");
            
        var backupExists:Bool = FileSystem.exists(location + ".backup");
        if (backupExists == false) {
            log("Backing up existing haxe");
            try {
                if (FileSystem.exists(location)) {
                    File.copy(location, location + ".backup");
                    FileSystem.deleteFile(location);
                }
            } catch (e) {
                log("");
                log("ERROR: could not delete existing haxe, it's likely it was locked by another process.");
                log("");
                log("       If you are using and IDE it's possible it has locked this folder");
                log("       Closing the IDE and re-running the command may fix the issue");
                return;
            }
        }

        backupExists = FileSystem.exists(haxelibLocation + ".backup");
        if (backupExists == false) {
            log("Backing up existing haxelib");
            try {
                if (FileSystem.exists(haxelibLocation)) {
                    File.copy(haxelibLocation, haxelibLocation + ".backup");
                    if (FileSystem.exists(haxelibTempLocation)) {
                        // haxelib.temp is the running process, so haxelib.exe is safe to delete
                        FileSystem.deleteFile(haxelibLocation);
                    } else {
                        // haxelib.exe is the running process, so rename it to haxelib.temp and move it to the hvm compilers dir
                        FileSystem.rename(haxelibLocation, haxelibTempLocation);
                    }
                }
            } catch (e) {
                log("");
                log("ERROR: could not backup haxelib, it's likely it was locked by another process.");
                log("");
                log("       If you are using and IDE it's possible it has locked this folder");
                log("       Closing the IDE and re-running the command may fix the issue");
                return;
            }
        }
		
        backupExists = FileSystem.exists(haxeStdLocation + ".backup");
        if (backupExists == false) {
            log("Backing up existing haxe std folder");
            try {
                FileSystem.rename(haxeStdLocation, haxeStdLocation + ".backup");
            } catch (e) {
                log("");
                log("ERROR: could not rename haxe std folder, it's likely it was locked by another process.");
                log("");
                log("       If you are using and IDE it's possible it has locked this folder");
                log("       Closing the IDE and re-running the command may fix the issue");
                return;
            }
        }

        backupExists = FileSystem.exists(nekoLocation + ".backup");
        if (backupExists == false) {
            log("Backing up existing neko folder");
            try {
                FileSystem.rename(nekoLocation, nekoLocation + ".backup");
            } catch (e) {
                log("");
                log("ERROR: could not rename neko folder, it's likely it was locked by another process.");
                log("");
                log("       If you are using and IDE it's possible it has locked this folder");
                log("       Closing the IDE and re-running the command may fix the issue");
                return;
            }
        }
        
        log("Deleting existing haxe");
        if (FileSystem.exists(location)) {
            FileSystem.deleteFile(location);
        }
        if (FileSystem.exists(haxelibLocation)) {
            FileSystem.deleteFile(haxelibLocation);
        }
        
        var safeHaxeVersion = StringTools.replace(version, ".", ",");
        var newHaxeLocation = Path.normalize(compilersDir + "/" + safeHaxeVersion + "/haxe.exe");
        createSymLink(location, newHaxeLocation);

        var newHaxelibLocation = Path.normalize(compilersDir + "/" + safeHaxeVersion + "/haxelib.exe");
        createSymLink(haxelibLocation, newHaxelibLocation);
        
        var newStdLocation = Path.normalize(compilersDir + "/" + safeHaxeVersion + "/std");
        createSymLink(haxeStdLocation, newStdLocation);

        createSymLink(nekoLocation, newNekoLocation);
        
        log("Success! Current haxe version: " + currentHaxeVersion + " | Current neko version: " + currentNekoVersion);
    }
    
    public static function installNightly(version:String) {
        if (!checkPrerequisites()) {
            return;
        }

        downloadNightly(version);

        var newNekoLocation:String = downloadNeko(version);
		
		restoreBackup();
        
        var location = haxeLocation;
        var pathParts = location.split("/");
        pathParts.pop();
        var haxeStdLocation = Path.normalize(pathParts.join("/") + "/std");
        var haxelibLocation = Path.normalize(pathParts.join("/") + "/haxelib.exe");
        pathParts.pop();
        var nekoLocation = Path.normalize(pathParts.join("/") + "/neko");

        var backupExists:Bool = FileSystem.exists(location + ".backup");
        if (backupExists == false) {
            log("Backing up existing haxe");
            try {
                if (FileSystem.exists(location)) {
                    File.copy(location, location + ".backup");
                    FileSystem.deleteFile(location);
                }
            } catch (e) {
                log("");
                log("ERROR: could not delete existing haxe, it's likely it was locked by another process.");
                log("");
                log("       If you are using and IDE it's possible it has locked this folder");
                log("       Closing the IDE and re-running the command may fix the issue");
                return;
            }
        }

        backupExists = FileSystem.exists(haxelibLocation + ".backup");
        if (backupExists == false) {
            log("Backing up existing haxelib");
            try {
                if (FileSystem.exists(haxelibLocation)) {
                    File.copy(haxelibLocation, haxelibLocation + ".backup");
                    if (FileSystem.exists(haxelibTempLocation)) {
                        // haxelib.temp is the running process, so haxelib.exe is safe to delete
                        FileSystem.deleteFile(haxelibLocation);
                    } else {
                        // haxelib.exe is the running process, so rename it to haxelib.temp and move it to the hvm compilers dir
                        FileSystem.rename(haxelibLocation, haxelibTempLocation);
                    }
                }
            } catch (e) {
                log("");
                log("ERROR: could not backup haxelib, it's likely it was locked by another process.");
                log("");
                log("       If you are using and IDE it's possible it has locked this folder");
                log("       Closing the IDE and re-running the command may fix the issue");
                return;
            }
        }
		
        backupExists = FileSystem.exists(haxeStdLocation + ".backup");
        if (backupExists == false) {
            log("Backing up existing haxe std folder");
            try {
                FileSystem.rename(haxeStdLocation, haxeStdLocation + ".backup");
            } catch (e) {
                log("");
                log("ERROR: could not rename haxe std folder, it's likely it was locked by another process.");
                log("");
                log("       If you are using and IDE it's possible it has locked this folder");
                log("       Closing the IDE and re-running the command may fix the issue");
                return;
            }
        }

        backupExists = FileSystem.exists(nekoLocation + ".backup");
        if (backupExists == false) {
            log("Backing up existing neko folder");
            try {
                FileSystem.rename(nekoLocation, nekoLocation + ".backup");
            } catch (e) {
                log("");
                log("ERROR: could not rename neko folder, it's likely it was locked by another process.");
                log("");
                log("       If you are using and IDE it's possible it has locked this folder");
                log("       Closing the IDE and re-running the command may fix the issue");
                return;
            }
        }
        
        log("Deleting existing haxe");
        if (FileSystem.exists(location)) {
            FileSystem.deleteFile(location);
        }
        if (FileSystem.exists(haxelibLocation)) {
            FileSystem.deleteFile(haxelibLocation);
        }
        
        var safeHaxeVersion = StringTools.replace(version, ".", ",");
        var newHaxeLocation = Path.normalize(compilersDir + "/" + safeHaxeVersion + "/haxe.exe");
        createSymLink(location, newHaxeLocation);

        var newHaxelibLocation = Path.normalize(compilersDir + "/" + safeHaxeVersion + "/haxelib.exe");
        createSymLink(haxelibLocation, newHaxelibLocation);
        
        var newStdLocation = Path.normalize(compilersDir + "/" + safeHaxeVersion + "/std");
        createSymLink(haxeStdLocation, newStdLocation);

        createSymLink(nekoLocation, newNekoLocation);
        
        log("Success! Current haxe version: " + currentHaxeVersion + " | Current neko version: " + currentNekoVersion);
    }
    
    public static function downloadOfficial(version:String) {
        var srcUrl = "https://github.com/HaxeFoundation/haxe/releases/download/" + version + "/";
        var srcFile = "haxe-" + version + "-";
        
        switch (system) {
            case Linux:
                srcFile += "linux64.tar.gz";
            case Windows:
                srcFile += "win64.zip";
            case Mac:
                srcFile += "osx.tar.gz";
            case Unknown:    
                throw "Unknown system!";
        }
        
        srcUrl += srcFile;
        log("Downloading official haxe " + version);
        
        var dstFile = Path.normalize(compilersDir + "/" + srcFile);
        if (FileSystem.exists(dstFile) == false) {
            downloadFile(srcUrl, dstFile);
        } else {
            log("Destination archive already exists, skipping download");
        }

        var safeHaxeVersion = StringTools.replace(version, ".", ",");
        var expandedDir = Path.normalize(compilersDir + "/" + safeHaxeVersion);
        if (FileSystem.exists(expandedDir) == false) {
            unzipFile(dstFile, expandedDir, true);
        } else {
            if (FileSystem.readDirectory(expandedDir).length == 0) {
                unzipFile(dstFile, expandedDir, true);
            } else {
                log("Expanded archive already exists, skipping unzip");
            }
        }
    }
    
    public static function downloadNightly(version:String) {
        var srcUrl = "https://build.haxe.org/builds/haxe/";
        switch (system) {
            case Linux:
                srcUrl += "linux64/";
            case Windows:
                srcUrl += "windows64/";
            case Mac:
                srcUrl += "mac/";
            case Unknown:    
                throw "Unknown system!";
        }
        
        
        var srcFile = "haxe_" + version;
        
        switch (system) {
            case Linux:
                srcFile += ".tar.gz";
            case Windows:
                srcFile += ".zip";
            case Mac:
                srcFile += ".tar.gz";
            case Unknown:    
                throw "Unknown system!";
        }
        
        srcUrl += srcFile;
        log("Downloading nightly haxe " + version);
        
        var dstFile = Path.normalize(compilersDir + "/" + srcFile);
        if (FileSystem.exists(dstFile) == false) {
            downloadFile(srcUrl, dstFile);
        } else {
            log("Destination archive already exists, skipping download");
        }
        
        var safeHaxeVersion = StringTools.replace(version, ".", ",");
        var expandedDir = Path.normalize(compilersDir + "/" + safeHaxeVersion);
        if (FileSystem.exists(expandedDir) == false) {
            unzipFile(dstFile, expandedDir, true);
        } else {
            if (FileSystem.readDirectory(expandedDir).length == 0) {
                unzipFile(dstFile, expandedDir, true);
            } else {
                log("Expanded archive already exists, skipping unzip");
            }
        }
    }

    public static function downloadNeko(haxeVersion:String):String {
        var nekoVersion:String = null;
        var is64:Bool = false;
        var srcUrl:String = "https://github.com/HaxeFoundation/neko/releases/download/v";
        
        var http = new Http('https://raw.githubusercontent.com/HaxeFoundation/haxe/${haxeVersion.split("_").pop()}/Makefile');
        http.setHeader("User-Agent", "HVM");
        http.onStatus = function(status:Int) {
        }
        http.onData = function(data:String) {
            var n1 = data.indexOf("$(INSTALLER_TMP_DIR)/neko-");
            var n2 = data.indexOf("http", n1);
            var n3 = data.indexOf(" -O", n2);
            var n4 = data.indexOf("/neko-", n2);
            var n5 = data.indexOf("-", n4 + 6);
            nekoVersion = data.substring(n4 + 6, n5);
            srcUrl += StringTools.replace(nekoVersion, ".", "-") + "/";
            is64 = Std.parseFloat(nekoVersion) > 2.1 && data.substring(n2, n3).indexOf("64") > -1;
        }
        http.onError = function(error) {
            log("url: " + http.url);
            throw "    Problem listing official releases: " + error;
        }
        http.request();

        var srcFile = "neko-" + nekoVersion + "-";
        var ext:String = null;
        switch (system) {
            case Linux:
                ext = "linux64.tar.gz";
            case Windows:
                if (is64) {
                    ext = "win64.zip";
                } else {
                    ext = "win.zip";
                }
            case Mac:
                ext = "osx.tar.gz";
                if (is64) {
                    ext = "osx64.tar.gz";
                } else {
                    ext = "osx.tar.gz";
                }
            case Unknown:    
                throw "Unknown system!";
        }
        srcFile += ext;
        srcUrl += srcFile;

        log("Downloading official Neko " + nekoVersion);
        
        var safeHaxeVersion = StringTools.replace(haxeVersion, ".", ",");
        var dstFile = Path.normalize(compilersDir + "/" + safeHaxeVersion + "/" + srcFile);
        if (FileSystem.exists(dstFile) == false) {
            downloadFile(srcUrl, dstFile);
        } else {
            log("Destination archive already exists, skipping download");
        }

        var safeNekoVersion = StringTools.replace(nekoVersion, ".", ",");
        var expandedDir = Path.normalize(compilersDir + "/neko-" + safeNekoVersion);
        if (FileSystem.exists(expandedDir) == false) {
            unzipFile(dstFile, expandedDir, true);
        } else {
            if (FileSystem.readDirectory(expandedDir).length == 0) {
                unzipFile(dstFile, expandedDir, true);
            } else {
                log("Expanded archive already exists, skipping unzip");
            }
        }

        return expandedDir;
    }
    
    public static function downloadFile(srcUrl:String, dstFile:String, isRedirect:Bool = false) {
        if (isRedirect == false) {
            log("    " + srcUrl);
        }
        
        var http = new Http(srcUrl);
        var httpsFailed:Bool = false;
        var httpStatus:Int = -1;
        http.onStatus = function(status:Int) {
            httpStatus = status;
            if (status == 302) { // follow redirects
                var location = http.responseHeaders.get("location");
                if (location == null) {
                    location = http.responseHeaders.get("Location");
                }
                if (location != null) {
                    downloadFile(location, dstFile, true);
                } else {
                    throw "302 (redirect) encountered but no 'location' header found";
                }
            }
        }
        http.onBytes = function(bytes:Bytes) {
            if (httpStatus == 200) {
                log("    Download complete");
                File.saveBytes(dstFile, bytes);
            }
        }
        http.onError = function(error) {
            if (!httpsFailed && srcUrl.indexOf("https:") > -1) {
                httpsFailed = true;
                log("Problem downloading file using http secure: " + error);
                log("Trying again with http insecure...");
                downloadFile( StringTools.replace(srcUrl, "https", "http"), dstFile);
            } else {
                throw "    Problem downloading file: " + error;
            }
        }
        http.request();
    }
    
    // https://gist.github.com/ruby0x1/8dc3a206c325fbc9a97e
    private static function unzipFile(srcZip:String, dstDir:String, ignoreRootFolder:Bool = false) {
        log("Unzipping archive");
        FileSystem.createDirectory(dstDir);
        
        var inFile = sys.io.File.read(srcZip);
        var entries = haxe.zip.Reader.readZip(inFile);
        inFile.close();

        for(entry in entries) {
            var fileName = entry.fileName;
            if (fileName.charAt(0) != "/" && fileName.charAt(0) != "\\" && fileName.split("..").length <= 1) {
                var dirs = ~/[\/\\]/g.split(fileName);
                if ((ignoreRootFolder != false && dirs.length > 1) || ignoreRootFolder == false) {
                    if (ignoreRootFolder != false) {
                        dirs.shift();
                    }
                
                    var path = "";
                    var file = dirs.pop();
                    for (d in dirs) {
                        path += d;
                        sys.FileSystem.createDirectory(dstDir + "/" + path);
                        path += "/";
                    }
                
                    if (file == "") {
                        //if (path != "") log("    created " + path);
                            continue; // was just a directory
                    }
                    path += file;
                    //log("    unzip " + path);
                
                    var data = haxe.zip.Reader.unzip(entry);
                    var f = File.write(dstDir + "/" + path, true);
                    f.write(data);
                    f.close();
                }
            }
        } //_entry

        var contents = sys.FileSystem.readDirectory(dstDir);
        if (contents.length > 0) {
            log('Unzipped successfully to ${dstDir}: (${contents.length} top level items found)');
        } else {
            throw 'No contents found in "${dstDir}"';
        }
    }
    
    private static function createSymLink(src:String, target:String) {
        var dir = FileSystem.isDirectory(target);
        
        src = Path.normalize(src);
        var srcParts = src.split("/");
        var srcFile = srcParts.pop();
        var srcPath = srcParts.join("/");
        var cwd = Sys.getCwd();
        
        Sys.setCwd(srcPath);
        
        if (dir == false) {
            var output = new Process("mklink " + srcFile + " \"" + target + "\"").stdout.readAll().toString().trim();
            log(output);
        } else {
            var output = new Process("mklink /d " + srcFile + " \"" + target + "\"").stdout.readAll().toString().trim();
            log(output);
        }
        
        Sys.setCwd(cwd);
    }
    
    public static function log(s:String) {
        Sys.println("    " + s);
    }
}