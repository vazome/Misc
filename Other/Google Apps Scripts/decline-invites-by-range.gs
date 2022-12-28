// Author: n0rmzzz
// Modified by: vazome
// Google Apps Scripts
// Originally author implemented Out of Office scanning, but this feature didn't work for me
// So I just removed it at all, because you already know your Out of Office dates and they can be provided explicitly at need.
// Though Out of Office scanning is a decent feature, maybe I will fix it.

var invited = "INVITED";
var accepted = "YES";
var acceptedStatus = CalendarApp.GuestStatus.YES;
var rejectedStatus = CalendarApp.GuestStatus.NO;
var invitedStatus = CalendarApp.GuestStatus.INVITED;
var maybeStatus = CalendarApp.GuestStatus.MAYBE;

var myName = 'John Bolton'; // <<<<<<<< Put your name here
var myEmail = 'foo@bar.bar'; // <<<<<<<< Put your email address here
var calendar = CalendarApp.getCalendarById(myEmail);

function processInvites() {
  var start = new Date('January 01, 2023 01:00:00 +0300');
  var end = new Date('January 09, 2023 01:00:00 +0300');
  var events = calendar.getEvents(start, end, {statusFilters: [acceptedStatus, maybeStatus]});
  processEventList(events);
  var invites = calendar.getEvents(start, end, invited);
  processEventList(invites);
}

function processEventList(eventList) {
  for (var i = 0; i < eventList.length; i++) {
    var event = eventList[i];
    var title = event.getTitle();
    var startTime = event.getStartTime();
    var endTime = event.getEndTime();
    var creators = event.getCreators();
    var status = event.getMyStatus();
    var isAllDay = event.isAllDayEvent();
    Logger.log("Processing: " + title + " from " + creators + " for " + startTime + " - " + endTime);
    event.setMyStatus(CalendarApp.GuestStatus.NO);
  }
}