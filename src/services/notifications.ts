export class NotificationService {
  send(msg: string) {
    console.log(msg);
  }
}

const getLastNotification = () => "You have a new message!";
