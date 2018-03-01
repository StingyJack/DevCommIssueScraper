namespace GetIssueDetails
{
    using System;
    using System.Collections.Generic;
    using System.Diagnostics;
    using System.Globalization;
    using System.IO;
    using System.Linq;
    using System.Net.Http;
    using System.Text;
    using System.Threading;
    using System.Threading.Tasks;
    using HtmlAgilityPack;
    using Newtonsoft.Json;

    internal class Program
    {
        private static readonly HttpClient _httpClient = new HttpClient();
        private static int _currentIssueProcessedCount;
        private static int _maxDop = 1;
        private static int _activeThreads;

        private static void Main(string[] args)
        {
            var userIdNumber = args[0];
            if (args.Length > 1)
            {
                _maxDop = int.Parse(args[1]);
            }

            Console.WriteLine($"{DateTime.Now.ToLongTimeString()} - Getting issue list...");
            var issueList = GetIssueList(userIdNumber);
            Console.WriteLine($"{DateTime.Now.ToLongTimeString()} - Issue list received with {issueList.Count} issues");
            var opts = new ParallelOptions {MaxDegreeOfParallelism = _maxDop};
            var sw = Stopwatch.StartNew();
            Parallel.ForEach(issueList, opts, issue =>
            {
                Interlocked.Increment(ref _activeThreads);
                Console.WriteLine($"{DateTime.Now.ToLongTimeString()} - Getting details for issue {issue.IssueNum}.");
                GetAdditionalDetails(ref issue);
                Interlocked.Increment(ref _currentIssueProcessedCount);
                Console.WriteLine(
                    $"{DateTime.Now.ToLongTimeString()} - Details retrieved for issue {issue.IssueNum}. {_currentIssueProcessedCount} of {issueList.Count}. {_activeThreads} active threads");
                Interlocked.Decrement(ref _activeThreads);
            });
            sw.Stop();
            var fileName = $"c:\\temp\\issueList_{DateTime.Now.ToFileTime()}.json";
            Console.WriteLine($"{DateTime.Now.ToLongTimeString()} - issue details retrieved in {sw.Elapsed}, writing to {fileName}");
            var json = JsonConvert.SerializeObject(issueList, Formatting.Indented);

            File.WriteAllText(fileName, json);
        }

        private static List<Issue> GetIssueList(string userIdNumber)
        {
            var issueList = new List<Issue>();
            var epoch = DateTimeOffset.UtcNow.ToUnixTimeMilliseconds();
            var myIssuesLink = $"https://developercommunity.visualstudio.com/users/{userIdNumber}/userFollowedProblems.html?page=1&pageSize=0&t={epoch}";
            var resp = _httpClient.GetAsync(myIssuesLink).GetAwaiter().GetResult();
            var raw = resp.Content.ReadAsStreamAsync().GetAwaiter().GetResult();
            var parsed = new HtmlDocument();
            parsed.Load(raw);
            var nodeListItems = parsed.DocumentNode.Descendants().Where(d => d.HasClass("node-list-item")).ToList();

            foreach (var nodeListitem in nodeListItems)
            {
                var issue = new Issue();
                var issueIdNode = nodeListitem.ChildNodes[3].ChildNodes[1].ChildNodes[1].Attributes["href"].Value;

                issue.IssueLink = issueIdNode.Insert(0, "https://developercommunity.visualstudio.com");
                issue.IssueLinkHash = issue.IssueLink.GetHashCode();
                issue.IssueNum = issue.IssueLink.Substring("https://developercommunity.visualstudio.com/content/problem/".Length);
                issue.IssueNum = issue.IssueNum.Substring(0, issue.IssueNum.IndexOf("/", StringComparison.Ordinal));
                issue.Title = nodeListitem.ChildNodes[3].ChildNodes[1].ChildNodes[1].InnerText.Trim();
                if (issue.Title.StartsWith("[", StringComparison.OrdinalIgnoreCase))
                {
                    var endIndex = issue.Title.IndexOf("]", 1, StringComparison.OrdinalIgnoreCase);
                    if (endIndex < 0)
                    {
                        Process.Start(issue.IssueLink);
                        throw new ArgumentException($"Issue {issue.IssueNum} does not have closing tag bracket");
                    }

                    issue.MyTag = issue.Title.Substring(1, endIndex - 1);
                    issue.Title = issue.Title.Substring(endIndex + 1).Trim();
                }

                issue.Status = nodeListitem.ChildNodes[3].ChildNodes[9].InnerText;
                issue.LastUpdatedBy = nodeListitem.ChildNodes[5].ChildNodes[1].ChildNodes[1].InnerText;
                var rawDate = nodeListitem.ChildNodes[5].ChildNodes[1].ChildNodes.FirstOrDefault(c => c.HasAttributes && c.Attributes.Contains("title"))?.Attributes["title"]
                    .Value; //what kind of evil is this?
                issue.LastUpdatedDate = ParseDate(rawDate);

                issueList.Add(issue);
            }

            return issueList;
        }

        private static DateTime ParseDate(string rawDate)
        {
            if (rawDate.IndexOf("ago", StringComparison.OrdinalIgnoreCase) >= 0
                || rawDate.IndexOf("yesterday", StringComparison.OrdinalIgnoreCase) >= 0)
            {
                return DateTime.Now.AddDays(-1);
            }

            rawDate = rawDate.Replace("at", string.Empty).Trim();
            DateTime dummeh; 
            
            if (DateTime.TryParseExact(rawDate, "MMM dd  hh:mm tt", CultureInfo.InvariantCulture, DateTimeStyles.None, out dummeh))
            {
                return dummeh;
            }

            if (DateTime.TryParse(rawDate, out dummeh))
            {
                return dummeh;
            }

           
            throw new ArgumentException($"Cant parse '{rawDate}' to any known format");
        }

        private static void GetAdditionalDetails(ref Issue issue)
        {
            var resp = _httpClient.GetAsync(issue.IssueLink).GetAwaiter().GetResult();
            var raw = resp.Content.ReadAsStreamAsync().GetAwaiter().GetResult();

            var parsed = new HtmlDocument();
            parsed.Load(raw);
            //File.WriteAllText($"Issue{issue.IssueNum}.html", parsed.DocumentNode.OuterHtml);

            var problemBodyBlock = parsed.DocumentNode.Descendants().First(e => e.HasClass("problem-body") && e.HasClass("node-body")); //problem-body node-body
            var authorInfoBlock = problemBodyBlock.ChildNodes[1];
            
            issue.Author = authorInfoBlock.ChildNodes[1].ChildNodes[3].InnerText;
            issue.CreatedDate = ParseDate(authorInfoBlock.ChildNodes[3].InnerText);
            issue.MsftTagList = authorInfoBlock.ChildNodes[5].ChildNodes.Where(c => c.HasClass("tag")).Select(c => c.InnerText).ToList();
            var issueText = new StringBuilder();
            for (int i = 2; i < problemBodyBlock.ChildNodes.Count; i++) //start after author info
            {
                var issueBodyLine = problemBodyBlock.ChildNodes[i].InnerText.Trim();
                if (string.IsNullOrWhiteSpace(issueBodyLine) && issueText.Length == 0)
                {
                    continue;
                }
                issueText.AppendLine(issueBodyLine);
            }

            issue.Text = issueText.ToString();
        }
    }
}