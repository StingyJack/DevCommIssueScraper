namespace GetIssueDetails
{
    using System;
    using System.Collections.Generic;
    using System.Linq;

    public class Issue : Message
    {
        public string Title { get; set; }
        public string Status { get; set; }
        public string IssueLink { get; set; }
        public int IssueLinkHash { get; set; }
        public string IssueNum { get; set; }


        public DateTime ReportedDate => CreatedDate;
        public int DaysSinceOpen => ReportedDate == DateTime.MinValue ? -999 : Convert.ToInt32(DateTime.Now.Subtract(ReportedDate).TotalDays);
        public int DaysSinceLastUpdated => LastUpdatedDate == DateTime.MinValue ? -999 : Convert.ToInt32(DateTime.Now.Subtract(LastUpdatedDate).TotalDays);

        public string MyTag { get; set; }

        public bool HasMyTag(string tagName)
        {
            // R#.... because this is any more readable? 
            //  return !string.IsNullOrWhiteSpace(MyTag) && MyTag.IndexOf(tagName, StringComparison.OrdinalIgnoreCase) >= 0;
            // how many people just Alt-Enter this into the one above?

            // ReSharper disable SimplifyConditionalTernaryExpression
            return string.IsNullOrWhiteSpace(MyTag) ? false : MyTag.IndexOf(tagName, StringComparison.OrdinalIgnoreCase) >= 0;
            // ReSharper restore SimplifyConditionalTernaryExpression
        }

        public List<string> MsftTagList { get; set; } = new List<string>();

        public bool HasMsftTag(string tagName)
        {
            return MsftTagList.Any(t => string.Equals(t, tagName, StringComparison.OrdinalIgnoreCase));
        }
    }
}