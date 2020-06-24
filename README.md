# DevCommIssueScraper
Makes https://developercommunity.visualstudio.com a bit more usable if you have many issues open. Compile the console
application, set your name and ID in a powershell script, then run that script to fetch  the issues and generate an html page
with summaries and details. Most importantly it will help you know what you need to provide updates for, and what to follow up on. 

This is what part of the html report looks like. 
![ooh doo doo brown](https://github.com/StingyJack/DevCommIssueScraper/blob/master/doc/issue_list_example.png?raw=true)

Since the list of "topics" (aka tags) on devcomm is horridly limited, and I cant do anything about what status is set on an item, 
I've taken the approach of adding tags in the titles. A few examples 
- [NEW]  is an item that has been reported, but no meaningful response has been offered. 
- [PERMA TRIAGE] is an item that has been marked as triage for more than a few weeks. 
- [CLOSED] I agree the issue is closed, so the script won't bother with checking if updates are needed for these.
- [INFO PROVIDED] When a mod sets an issue to "Need more info" and you provide requested info, the system doesn't recognize that you did.
Rather than have the item in a list of things I need to update (as the status says), this tag puts it in the MSFT needs to update pile.
- ... etc

Make up your own if you want. The script is pretty straight forward. I had it getting issues in a script too, but it was taking 4+ 
minutes to get all the details, and powershell is ass at multithreading locally, so the console app is doing the scraping and the script
just calls it and does the massaging. 


