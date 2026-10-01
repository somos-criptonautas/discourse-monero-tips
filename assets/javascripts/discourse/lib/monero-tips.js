// The address rides along with the post stream (TopicView preloads it for every
// author on the page) and with the user serializer on a profile, so neither
// place needs a request to decide whether to show the button.
export function postAddress(post) {
  return post?.user_custom_fields?.monero_address;
}

export function userAddress(user) {
  return user?.custom_fields?.monero_address;
}
