export type Rating = "love" | "maybe" | "not_interested";

export const RATING_OPTIONS: { value: Rating; label: string; points: string }[] = [
  { value: "love", label: "Love it", points: "+2" },
  { value: "maybe", label: "Maybe", points: "+1" },
  { value: "not_interested", label: "Not interested", points: "-2" },
];

export type Suggestion = {
  id: number;
  title: string;
  score: number;
  votes_count: number;
  my_rating: Rating | null;
  suggested_by: string | null;
  can_remove: boolean;
};

export type VotingGroup = {
  id: number;
  name: string;
  is_owner: boolean;
};
