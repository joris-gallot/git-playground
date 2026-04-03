export class NotificationService {
  send(msg: string) {
    console.log(msg);
  }
}

export const notificationService = new NotificationService();
