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
  owner_id: number;
  member_count: number;
};

export type GroupDetails = {
  id: number;
  name: string;
  owner_id: number;
  members: { id: number; display_name: string }[];
  invitation_code?: string;
};
