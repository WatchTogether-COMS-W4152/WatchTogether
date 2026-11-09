export type FlashData = {
  notice?: string;
  alert?: string;
};

export type User = {
  id: number;
  display_name: string;
  email: string;
};

export type SharedProps = {
  auth: { user: User | null };
  flash: FlashData;
};

export type GroupSummary = {
  id: number;
  name: string;
  is_owner: boolean;
  member_count: number;
};

export type GroupDetails = {
  id: number;
  name: string;
  is_owner: boolean;
  members: { id: number; display_name: string; role: "owner" | "member" }[];
  invitation_code?: string;
};
