type Props = { title: string };

export function App({ title }: Props) {
  return <button className="btn">{title}</button>;
}
