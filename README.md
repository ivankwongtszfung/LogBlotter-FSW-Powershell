# LogBlotter
File System Watcher integrated with WPF GUI running in Powershell.

## Reference
I am a new-joiner to the Powershell Family. I read a lot of googles, stack Overflows, ss64 to complete the whole program.
The URL below is the one I found most useful and I reference some part of my code from them:

About Powershell:  <https://ss64.com/ps/>

Everything related to runspace:

About the Runspace: <https://learn-powershell.net/2012/10/14/powershell-and-wpf-writing-data-to-a-ui-from-a-different-runspace/>

About the Runspace & Oberservable: <https://learn-powershell.net/2012/12/08/powershell-and-wpf-listbox-part-2datatriggers-and-observablecollection/>

Everything related to File System Watcher:

<https://referencesource.microsoft.com/#system/services/io/system/io/FileSystemWatcher.cs>

They are all great guys, credits on them.

## Feature
### XAML in Powershell
We can use the C# library to read the XAML so that we can make a form using WPF.
After we know that we can make a DataGrid to display all the data I store in an observable.
This is only a lame DataGrid, just to demo the work.
### File System Watching (FSW)
This is a brief introduction on what you can do with this File system watcher, for more information please read the documentation Written in MSDN
* Filter : to filter the files you want to watch using regex, e.g. *.log, *.txt, *.abc 
* Path : the path which the file located, Network Path is also acceptable (To someone it may conern)
* IncludeSubdirectories : whether you want to watch all the sub directories in that Path.
* NotifyFilter : what property you want to watch for: LastAccess , LastWrite, FileName , DirectoryName...

I only use the FSW to watch the content changes in the log files, but we can monitor for the Create, Change, Delete of files and I register an event so it will update my internal object when something changes.
### Communication between different Runspace
If you use a [Dispatcher](https://docs.microsoft.com/en-us/dotnet/api/system.windows.threading.dispatcher?view=netframework-4.8) which is more or less a messager to the XAML Form, it would takes some time and it would be worse if it grows bigger so you have multiple runspace communication, which causes some runspace violation, if the communication is two different runspace.(not created)

To use dispatcher it may takes a lot of times to run only one small update (which will stuck the FSW Event, pipeline overflow eventually) so I use a Timer Dispatcher, which will run every specific amount of time you decide and if the action is small enough it will work smoother than the normal dispatcher.

(This is only my personal experience, this may not be always correct, but this is worth to take into account.)
My default is 10s for every update

