export class NotificationService {
  send(msg: string) {
    console.log(msg, "- sent at", new Date().toISOString());
  }
}

const getLastNotification = () => "You have a new message!";
