namespace GetIssueDetails
{
    using System;
    using System.Collections.Generic;

    public class Message
    {
        public string Author { get; set; }
        public string Text { get; set; }
        public DateTime CreatedDate { get; set; }
        public DateTime LastUpdatedDate { get; set; }
        public string LastUpdatedBy { get; set; }
        public List<Message> Replies { get; set; }
        public Message Parent { get; set; }
    }
}